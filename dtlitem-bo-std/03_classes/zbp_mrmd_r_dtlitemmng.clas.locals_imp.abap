*"* Local Types of ZBP_MRMD_R_DTLITEMMNG
*"* [표준] 표준 POST / PATCH / DELETE 버전
*"*   SaveAll이 하던 판단(존재 여부, 하위 존재, 공통코드)을 프레임워크 + precheck + validation으로 나눔
*"*   $batch changeset 하나 = 한 LUW: 하나라도 실패하면 전체 롤백

CLASS lhc_mng DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR Mng RESULT result.

    " [표준 #2] SaveAll 메서드 제거

    " [표준 #3] Mng 삭제 전 하위 담당자 확인
    METHODS precheck_delete FOR PRECHECK
      IMPORTING keys FOR DELETE Mng.

    " [표준 #4] 생성 시 유효성 체크 (ItemGroupCode 공통코드 + DetailedItemGroupCode 자리)
    METHODS validateOnCreate FOR VALIDATE ON SAVE
      IMPORTING keys FOR Mng~validateOnCreate.

    METHODS setCreateStamp FOR DETERMINE ON SAVE
      IMPORTING keys FOR Mng~setCreateStamp.

    METHODS setChangeStamp FOR DETERMINE ON SAVE
      IMPORTING keys FOR Mng~setChangeStamp.
ENDCLASS.


CLASS lhc_mng IMPLEMENTATION.

  METHOD get_global_authorizations.
    " [표준 #2] action 대신 create/update/delete 권한
    "  담당자 생성(create by _User)은 strict 모드에서 Mng의 update 권한으로 판단됨
    result = VALUE #( %create = if_abap_behv=>auth-allowed
                      %update = if_abap_behv=>auth-allowed
                      %delete = if_abap_behv=>auth-allowed ).
  ENDMETHOD.


  METHOD precheck_delete.
    " [표준 #3] SaveAll의 "하위 User가 남으면 삭제 금지"
    "  - 트랜잭션 버퍼 기준으로 읽음: 같은 changeset에서 앞서 DELETE한 담당자는 이미 빠져 있음
    "    → 담당자를 전부 DELETE한 뒤 Mng DELETE를 보내면 삭제됨 (요청 순서 중요)
    "  - 그대로 두면 composition이라 Mng 삭제 시 담당자도 함께 지워지므로 여기서 막음
    READ ENTITIES OF zmrmd_r_dtlitemmng IN LOCAL MODE
      ENTITY Mng BY \_User
      FIELDS ( UserID )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_child).

    LOOP AT keys INTO DATA(ls_key).
      IF line_exists( lt_child[ CompanyCode           = ls_key-CompanyCode
                                ItemGroupCode         = ls_key-ItemGroupCode
                                DetailedItemGroupCode = ls_key-DetailedItemGroupCode ] ).
        APPEND VALUE #( %tky = ls_key-%tky ) TO failed-mng.
        APPEND VALUE #( %tky = ls_key-%tky
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = |세부품목그룹 { ls_key-DetailedItemGroupCode }에 담당자가 있어 삭제할 수 없습니다| ) )
               TO reported-mng.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD validateOnCreate.
    " [표준 #4] SaveAll [유효성 체크 #1] ItemGroupCode 공통코드 체크를 그대로 옮김 (내부 테이블 조인)
    "  공통코드(ZMRMD_I_ZTMRMD00740)에서
    "  CodeClass = 'PQMD1010', UsedCheck = 'X', Attribute03 = 'SUB',
    "  Attribute04 = 회사코드, Attribute041 = 품목그룹코드 인 행이 있어야 함
    TYPES: BEGIN OF ty_igc_key,
             CompanyCode   TYPE bukrs,
             ItemGroupCode TYPE zdemr_item_grp_cd,
           END OF ty_igc_key.
    DATA lt_igc_key TYPE STANDARD TABLE OF ty_igc_key WITH EMPTY KEY.
    DATA lt_igc_ok  TYPE SORTED TABLE OF ty_igc_key WITH UNIQUE KEY CompanyCode ItemGroupCode.

    READ ENTITIES OF zmrmd_r_dtlitemmng IN LOCAL MODE
      ENTITY Mng
      FIELDS ( CompanyCode ItemGroupCode DetailedItemGroupCode )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_mng).

    lt_igc_key = VALUE #( FOR m IN lt_mng ( CompanyCode   = m-CompanyCode
                                            ItemGroupCode = m-ItemGroupCode ) ).
    IF lt_igc_key IS NOT INITIAL.
      SELECT DISTINCT d~CompanyCode, d~ItemGroupCode
        FROM @lt_igc_key AS d
        INNER JOIN zmrmd_i_ztmrmd00740 AS c
          ON  c~Attribute04  = d~CompanyCode       " CHAR 40 = bukrs
          AND c~Attribute041 = d~ItemGroupCode     " CHAR 40 = zdemr_item_grp_cd
        WHERE c~CodeClass   = 'PQMD1010'
          AND c~UsedCheck   = 'X'
          AND c~Attribute03 = 'SUB'
        INTO TABLE @lt_igc_ok.
      " ON 절 타입 비교 오류가 나면 아래처럼 CAST로 맞추세요
      "   ON  c~Attribute04  = CAST( d~CompanyCode   AS CHAR( 40 ) )
      "   AND c~Attribute041 = CAST( d~ItemGroupCode AS CHAR( 40 ) )
    ENDIF.

    LOOP AT lt_mng INTO DATA(ls_m).
      IF NOT line_exists( lt_igc_ok[ CompanyCode   = ls_m-CompanyCode
                                     ItemGroupCode = ls_m-ItemGroupCode ] ).
        APPEND VALUE #( %tky = ls_m-%tky ) TO failed-mng.
        APPEND VALUE #( %tky = ls_m-%tky
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = |[ItemGroupCode] { ls_m-ItemGroupCode } does not exist.| )
                        %element-ItemGroupCode = if_abap_behv=>mk-on ) TO reported-mng.
        CONTINUE.
      ENDIF.

      "▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼
      " [유효성 체크 위치 #2] DetailedItemGroupCode
      "  [표준 #6] 빈 값은 허용하므로 체크하지 않고 넘어감
      "    IF ls_m-DetailedItemGroupCode IS INITIAL. CONTINUE. ENDIF.
      "  - ls_m-DetailedItemGroupCode 형식/허용값 확인 (예: 도메인 고정값, 코드 규칙)
      "  - 실패 시: 위와 같은 형태로 failed-mng, reported-mng에 추가
      "      text = |세부품목그룹코드 { ls_m-DetailedItemGroupCode }가 유효하지 않습니다|
      "      %element-DetailedItemGroupCode = if_abap_behv=>mk-on
      "▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲
    ENDLOOP.
  ENDMETHOD.


  METHOD setCreateStamp.
    DATA(lv_date) = cl_abap_context_info=>get_system_date( ).
    DATA(lv_time) = cl_abap_context_info=>get_system_time( ).
    DATA(lv_user) = cl_abap_context_info=>get_user_technical_name( ).

    MODIFY ENTITIES OF zmrmd_r_dtlitemmng IN LOCAL MODE
      ENTITY Mng
      UPDATE FIELDS ( CreatedDate CreatedTime CreatedBy )
      WITH VALUE #( FOR k IN keys ( %tky        = k-%tky
                                    CreatedDate = lv_date
                                    CreatedTime = lv_time
                                    CreatedBy   = lv_user ) ).
  ENDMETHOD.


  METHOD setChangeStamp.
    DATA(lv_date) = cl_abap_context_info=>get_system_date( ).
    DATA(lv_time) = cl_abap_context_info=>get_system_time( ).
    DATA(lv_user) = cl_abap_context_info=>get_user_technical_name( ).

    MODIFY ENTITIES OF zmrmd_r_dtlitemmng IN LOCAL MODE
      ENTITY Mng
      UPDATE FIELDS ( ChangedDate ChangedTime ChangedBy )
      WITH VALUE #( FOR k IN keys ( %tky        = k-%tky
                                    ChangedDate = lv_date
                                    ChangedTime = lv_time
                                    ChangedBy   = lv_user ) ).
  ENDMETHOD.

ENDCLASS.


CLASS lhc_user DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    " [표준 #4] 담당자 생성 시 유효성 체크 자리
    METHODS validateOnCreate FOR VALIDATE ON SAVE
      IMPORTING keys FOR User~validateOnCreate.

    " [표준 #7] 담당자 삭제 전 키 4개 빈 값 체크
    METHODS precheck_delete FOR PRECHECK
      IMPORTING keys FOR DELETE User.

    METHODS setCreateStamp FOR DETERMINE ON SAVE
      IMPORTING keys FOR User~setCreateStamp.
ENDCLASS.


CLASS lhc_user IMPLEMENTATION.

  METHOD validateOnCreate.
    READ ENTITIES OF zmrmd_r_dtlitemmng IN LOCAL MODE
      ENTITY User
      FIELDS ( UserID )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_user).

    LOOP AT lt_user INTO DATA(ls_u).
      " [표준 #7] 키 4개 필수 체크 (빈 값이면 오류)
      IF ls_u-CompanyCode           IS INITIAL
      OR ls_u-ItemGroupCode         IS INITIAL
      OR ls_u-DetailedItemGroupCode IS INITIAL
      OR ls_u-UserID                IS INITIAL.
        APPEND VALUE #( %tky = ls_u-%tky ) TO failed-user.
        APPEND VALUE #( %tky = ls_u-%tky
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = |담당자: 회사코드, 품목그룹코드, 세부품목그룹코드, 사번은 필수입니다| ) )
               TO reported-user.
        CONTINUE.
      ENDIF.

      "▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼
      " [유효성 체크 위치 #3] UserID (담당자 사번)
      "  - ls_u-UserID 가 유효한 사번/사용자인지 확인 (예: 사용자 마스터, 인사 데이터)
      "  - 실패 시:
      "      APPEND VALUE #( %tky = ls_u-%tky ) TO failed-user.
      "      APPEND VALUE #( %tky = ls_u-%tky
      "                      %msg = new_message_with_text(
      "                               severity = if_abap_behv_message=>severity-error
      "                               text     = |사번 { ls_u-UserID }가 유효하지 않습니다| )
      "                      %element-UserID = if_abap_behv=>mk-on ) TO reported-user.
      "▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲
    ENDLOOP.
  ENDMETHOD.


  METHOD precheck_delete.
    " [표준 #7] DELETE User(CompanyCode='..',ItemGroupCode='..',DetailedItemGroupCode='..',UserID='..')
    "  키 중 하나라도 빈 값('')이면 삭제하지 않음
    LOOP AT keys INTO DATA(ls_key).
      IF ls_key-CompanyCode           IS INITIAL
      OR ls_key-ItemGroupCode         IS INITIAL
      OR ls_key-DetailedItemGroupCode IS INITIAL
      OR ls_key-UserID                IS INITIAL.
        APPEND VALUE #( %tky = ls_key-%tky ) TO failed-user.
        APPEND VALUE #( %tky = ls_key-%tky
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = |담당자 삭제: 회사코드, 품목그룹코드, 세부품목그룹코드, 사번은 필수입니다| ) )
               TO reported-user.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD setCreateStamp.
    DATA(lv_date) = cl_abap_context_info=>get_system_date( ).
    DATA(lv_time) = cl_abap_context_info=>get_system_time( ).
    DATA(lv_user) = cl_abap_context_info=>get_user_technical_name( ).

    MODIFY ENTITIES OF zmrmd_r_dtlitemmng IN LOCAL MODE
      ENTITY User
      UPDATE FIELDS ( CreatedDate CreatedTime CreatedBy )
      WITH VALUE #( FOR k IN keys ( %tky        = k-%tky
                                    CreatedDate = lv_date
                                    CreatedTime = lv_time
                                    CreatedBy   = lv_user ) ).
  ENDMETHOD.

ENDCLASS.
