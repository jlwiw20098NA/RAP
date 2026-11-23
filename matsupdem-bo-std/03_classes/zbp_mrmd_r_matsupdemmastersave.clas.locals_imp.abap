*"* Local Types of ZBP_MRMD_R_MATSUPDEMMASTERSAVE  [표준 CRUD 버전]
*"* - lhc_matsup : 생성 시 필수/중복/유효성 체크 (validation)
*"* - lsc_matsup : 같은 트랜잭션에서 00420(이력) 저장 (with additional save)
*"* $batch changeset 안에서 하나라도 실패하면 00410, 00420 모두 저장되지 않음

CLASS lhc_matsup DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR MatSup RESULT result.

    " [수정 #1] 생성/변경 일시·사용자
    METHODS setCreateStamp FOR DETERMINE ON SAVE
      IMPORTING keys FOR MatSup~setCreateStamp.
    METHODS setChangeStamp FOR DETERMINE ON SAVE
      IMPORTING keys FOR MatSup~setChangeStamp.

    METHODS validateOnCreate FOR VALIDATE ON SAVE
      IMPORTING keys FOR MatSup~validateOnCreate.

    " [수정 #3] 삭제된 데이터 수정·재삭제 방지
    METHODS validateOnUpdate FOR VALIDATE ON SAVE
      IMPORTING keys FOR MatSup~validateOnUpdate.
ENDCLASS.


CLASS lhc_matsup IMPLEMENTATION.

  METHOD get_global_authorizations.
    result = VALUE #( %create = if_abap_behv=>auth-allowed
                      %update = if_abap_behv=>auth-allowed ).   " [수정 #3] delete 제거
  ENDMETHOD.


  METHOD validateOnCreate.
    DATA: lv_error TYPE abap_boolean,
          lv_found TYPE abap_boolean.

    READ ENTITIES OF zmrmd_r_matsupdemmastersave IN LOCAL MODE
      ENTITY MatSup
      FIELDS ( CompanyCode Material Supplier GoodsSupplier DeletionIndicator )   " [수정 #3]
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_rows).

    LOOP AT lt_rows INTO DATA(ls).
      CLEAR lv_error.

      " [수정 #3] 생성할 때 삭제 상태로 만들 수 없음
      IF ls-DeletionIndicator = abap_true.
        APPEND VALUE #( %tky = ls-%tky
                        %msg = new_message_with_text( severity = if_abap_behv_message=>severity-error
                                                      text     = `[DeletionIndicator] 생성 시에는 삭제 상태로 등록할 수 없습니다.` )
                        %element-DeletionIndicator = if_abap_behv=>mk-on ) TO reported-matsup.
        lv_error = abap_true.
      ENDIF.

      "--------------------------------------------------------------
      " 1. 필수 입력 체크
      "--------------------------------------------------------------
      IF ls-CompanyCode IS INITIAL.
        APPEND VALUE #( %tky = ls-%tky
                        %msg = new_message_with_text( severity = if_abap_behv_message=>severity-error
                                                      text     = `[CompanyCode] is required.` )
                        %element-CompanyCode = if_abap_behv=>mk-on ) TO reported-matsup.
        lv_error = abap_true.
      ENDIF.
      IF ls-Material IS INITIAL.
        APPEND VALUE #( %tky = ls-%tky
                        %msg = new_message_with_text( severity = if_abap_behv_message=>severity-error
                                                      text     = `[Material] is required.` )
                        %element-Material = if_abap_behv=>mk-on ) TO reported-matsup.
        lv_error = abap_true.
      ENDIF.
      IF ls-Supplier IS INITIAL.
        APPEND VALUE #( %tky = ls-%tky
                        %msg = new_message_with_text( severity = if_abap_behv_message=>severity-error
                                                      text     = `[Supplier] is required.` )
                        %element-Supplier = if_abap_behv=>mk-on ) TO reported-matsup.
        lv_error = abap_true.
      ENDIF.
      IF ls-GoodsSupplier IS INITIAL.
        APPEND VALUE #( %tky = ls-%tky
                        %msg = new_message_with_text( severity = if_abap_behv_message=>severity-error
                                                      text     = `[GoodsSupplier] is required.` )
                        %element-GoodsSupplier = if_abap_behv=>mk-on ) TO reported-matsup.
        lv_error = abap_true.
      ENDIF.
      IF lv_error = abap_true.
        APPEND VALUE #( %tky = ls-%tky ) TO failed-matsup.
        CONTINUE.
      ENDIF.

      "--------------------------------------------------------------
      " 2. 중복 데이터 체크 (00410 키 기준, DB에 이미 있는지)
      "    managed도 같은 키 생성을 막지만, 메시지를 명확히 하려고 직접 확인
      "--------------------------------------------------------------
      " [수정 #3] 삭제된 데이터도 키가 남아 있으므로 메시지를 구분
      SELECT SINGLE DeletionIndicator FROM zmrmd_i_ztmrmd00410
        WHERE CompanyCode   = @ls-CompanyCode
          AND Material      = @ls-Material
          AND Supplier      = @ls-Supplier
          AND GoodsSupplier = @ls-GoodsSupplier
        INTO @DATA(lv_db_deleted).
      IF sy-subrc = 0.
        APPEND VALUE #( %tky = ls-%tky
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = COND #( WHEN lv_db_deleted = abap_true
                                                    THEN |삭제된 데이터와 키가 같아 등록할 수 없습니다 |
                                                    ELSE |이미 등록된 데이터입니다 | ) &&
                                            |({ ls-CompanyCode }/{ ls-Material }/{ ls-Supplier }/{ ls-GoodsSupplier })| ) )
               TO reported-matsup.
        APPEND VALUE #( %tky = ls-%tky ) TO failed-matsup.
        CONTINUE.
      ENDIF.

      "--------------------------------------------------------------
      " 3. 유효성 체크 (표준 뷰 DCL 우회: WITH PRIVILEGED ACCESS)
      "--------------------------------------------------------------
      " 회사코드
      CLEAR lv_found.
      SELECT SINGLE @abap_true FROM I_CompanyCode
        WHERE CompanyCode = @ls-CompanyCode
        INTO @lv_found
        WITH PRIVILEGED ACCESS.
      IF lv_found = abap_false.
        APPEND VALUE #( %tky = ls-%tky
                        %msg = new_message_with_text( severity = if_abap_behv_message=>severity-error
                                                      text     = |[CompanyCode] { ls-CompanyCode } does not exist.| )
                        %element-CompanyCode = if_abap_behv=>mk-on ) TO reported-matsup.
        lv_error = abap_true.
      ENDIF.

      " 자재
      CLEAR lv_found.
      SELECT SINGLE @abap_true FROM I_Product
        WHERE Product = @ls-Material
        INTO @lv_found
        WITH PRIVILEGED ACCESS.
      IF lv_found = abap_false.
        APPEND VALUE #( %tky = ls-%tky
                        %msg = new_message_with_text( severity = if_abap_behv_message=>severity-error
                                                      text     = |[Material] { ls-Material } does not exist.| )
                        %element-Material = if_abap_behv=>mk-on ) TO reported-matsup.
        lv_error = abap_true.
      ENDIF.

      " 공급업체
      CLEAR lv_found.
      SELECT SINGLE @abap_true FROM I_Supplier
        WHERE Supplier = @ls-Supplier
        INTO @lv_found
        WITH PRIVILEGED ACCESS.
      IF lv_found = abap_false.
        APPEND VALUE #( %tky = ls-%tky
                        %msg = new_message_with_text( severity = if_abap_behv_message=>severity-error
                                                      text     = |[Supplier] { ls-Supplier } does not exist.| )
                        %element-Supplier = if_abap_behv=>mk-on ) TO reported-matsup.
        lv_error = abap_true.
      ENDIF.

      " 물품공급업체
      CLEAR lv_found.
      SELECT SINGLE @abap_true FROM I_Supplier
        WHERE Supplier = @ls-GoodsSupplier
        INTO @lv_found
        WITH PRIVILEGED ACCESS.
      IF lv_found = abap_false.
        APPEND VALUE #( %tky = ls-%tky
                        %msg = new_message_with_text( severity = if_abap_behv_message=>severity-error
                                                      text     = |[GoodsSupplier] { ls-GoodsSupplier } does not exist.| )
                        %element-GoodsSupplier = if_abap_behv=>mk-on ) TO reported-matsup.
        lv_error = abap_true.
      ENDIF.

      IF lv_error = abap_true.
        APPEND VALUE #( %tky = ls-%tky ) TO failed-matsup.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  " [수정 #1] 생성 일시·사용자 (서버 시스템 시간)
  METHOD setCreateStamp.
    DATA(lv_date) = cl_abap_context_info=>get_system_date( ).
    DATA(lv_time) = cl_abap_context_info=>get_system_time( ).
    DATA(lv_user) = cl_abap_context_info=>get_user_technical_name( ).

    MODIFY ENTITIES OF zmrmd_r_matsupdemmastersave IN LOCAL MODE
      ENTITY MatSup
      UPDATE FIELDS ( CreatedDate CreatedTime CreatedBy )
      WITH VALUE #( FOR k IN keys ( %tky        = k-%tky
                                    CreatedDate = lv_date
                                    CreatedTime = lv_time
                                    CreatedBy   = lv_user ) ).
  ENDMETHOD.


  " [수정 #1] 변경 일시·사용자 (SupplyRatio, Remark가 바뀔 때)
  METHOD setChangeStamp.
    DATA(lv_date) = cl_abap_context_info=>get_system_date( ).
    DATA(lv_time) = cl_abap_context_info=>get_system_time( ).
    DATA(lv_user) = cl_abap_context_info=>get_user_technical_name( ).

    MODIFY ENTITIES OF zmrmd_r_matsupdemmastersave IN LOCAL MODE
      ENTITY MatSup
      UPDATE FIELDS ( ChangedDate ChangedTime ChangedBy )
      WITH VALUE #( FOR k IN keys ( %tky        = k-%tky
                                    ChangedDate = lv_date
                                    ChangedTime = lv_time
                                    ChangedBy   = lv_user ) ).
  ENDMETHOD.


  " [수정 #3] 이미 삭제된(DB 삭제지시자 X) 데이터는 수정·재삭제 불가
  "  - validation 시점에는 DB에 아직 이전 값이 있으므로 DB 값으로 판단
  "  - 이번 요청의 소프트 삭제(공백 → X) 자체는 DB 값이 공백이라 통과
  METHOD validateOnUpdate.
    LOOP AT keys INTO DATA(ls_key).
      SELECT SINGLE DeletionIndicator FROM zmrmd_i_ztmrmd00410
        WHERE CompanyCode   = @ls_key-CompanyCode
          AND Material      = @ls_key-Material
          AND Supplier      = @ls_key-Supplier
          AND GoodsSupplier = @ls_key-GoodsSupplier
        INTO @DATA(lv_db_deleted).
      IF sy-subrc = 0 AND lv_db_deleted = abap_true.
        APPEND VALUE #( %tky = ls_key-%tky ) TO failed-matsup.
        APPEND VALUE #( %tky = ls_key-%tky
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = |삭제된 데이터는 수정할 수 없습니다 | &&
                                            |({ ls_key-CompanyCode }/{ ls_key-Material }/{ ls_key-Supplier }/{ ls_key-GoodsSupplier })| ) )
               TO reported-matsup.
      ENDIF.
      CLEAR lv_db_deleted.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.


CLASS lsc_matsup DEFINITION INHERITING FROM cl_abap_behavior_saver.
  PROTECTED SECTION.
    METHODS save_modified REDEFINITION.
ENDCLASS.


CLASS lsc_matsup IMPLEMENTATION.

  METHOD save_modified.
    "================================================================
    " 00420 저장 (SaveAll 버전과 동일)
    "  C/U: 최종 상태를 로그 행으로 INSERT (TimeStamp = 저장 시각, UTC)   [수정 #2]
    "  D: 물리 삭제 없음. 00410 삭제지시자 'X' → 이전 로그 행 'X' + 새 로그 행(X) 생성   [수정 #3]
    "  생성/변경 일시·사용자(ERDAT/ERZET/ERNAM, AEDAT/AEZET/AENAM)도 함께 기록   [수정 #1]
    "  TODO: 테이블명(ztmrmd00420)과 컬럼명을 실제 값으로 맞추세요
    "================================================================
    DATA lt_hist TYPE STANDARD TABLE OF ztmrmd00420 WITH EMPTY KEY.
    DATA lv_ts   TYPE tzntstmps.

    GET TIME STAMP FIELD lv_ts.

    " [수정 #2] C/U 공통: 생성·수정된 행을 하나로 모아 00420에 로그 행을 쌓음
    "  - update-matsup에는 바뀐 필드만 값이 있어서, 최종 상태 전체를 READ ENTITIES로 다시 읽음
    "  - FOR 두 개를 연달아 쓰면 중첩 반복(곱집합)이 되므로 BASE로 이어 붙임
    DATA lt_keys TYPE TABLE FOR READ IMPORT zmrmd_r_matsupdemmastersave\\matsup.

    lt_keys = VALUE #( FOR c IN create-matsup
                       ( CompanyCode   = c-CompanyCode
                         Material      = c-Material
                         Supplier      = c-Supplier
                         GoodsSupplier = c-GoodsSupplier ) ).
    lt_keys = VALUE #( BASE lt_keys
                       FOR u IN update-matsup
                       ( CompanyCode   = u-CompanyCode
                         Material      = u-Material
                         Supplier      = u-Supplier
                         GoodsSupplier = u-GoodsSupplier ) ).

    IF lt_keys IS NOT INITIAL.
      READ ENTITIES OF zmrmd_r_matsupdemmastersave IN LOCAL MODE
        ENTITY MatSup
        ALL FIELDS WITH lt_keys
        RESULT DATA(lt_rows).

      " [수정 #3] 소프트 삭제(이번에 삭제지시자가 'X'로 바뀐 행): 이전 로그 행에도 'X'를 찍음 (기존 D 로직 유지)
      LOOP AT update-matsup INTO DATA(ls_d)
           WHERE %control-DeletionIndicator = if_abap_behv=>mk-on
             AND DeletionIndicator          = abap_true.
        READ TABLE lt_rows INTO DATA(ls_r)
             WITH KEY id COMPONENTS CompanyCode   = ls_d-CompanyCode
                                    Material      = ls_d-Material
                                    Supplier      = ls_d-Supplier
                                    GoodsSupplier = ls_d-GoodsSupplier.
        UPDATE ztmrmd00420
          SET del_ind = 'X',
              aedat   = @ls_r-ChangedDate,
              aezet   = @ls_r-ChangedTime,
              aenam   = @ls_r-ChangedBy
          WHERE bukrs       = @ls_d-CompanyCode
            AND matnr       = @ls_d-Material
            AND lifnr       = @ls_d-Supplier
            AND goods_lifnr = @ls_d-GoodsSupplier
            AND del_ind     = @space.
      ENDLOOP.

      " C/U(소프트 삭제 포함) 최종 상태를 새 로그 행으로 INSERT
      lt_hist = VALUE #( FOR r IN lt_rows
                         ( bukrs        = r-CompanyCode
                           matnr        = r-Material
                           lifnr        = r-Supplier
                           goods_lifnr  = r-GoodsSupplier
                           time_stamp   = lv_ts
                           supply_ratio = r-SupplyRatio
                           remark       = r-Remark
                           erdat        = r-CreatedDate
                           erzet        = r-CreatedTime
                           ernam        = r-CreatedBy
                           aedat        = r-ChangedDate
                           aezet        = r-ChangedTime
                           aenam        = r-ChangedBy
                           del_ind      = r-DeletionIndicator ) ).   " [수정 #3] 기존: space

      INSERT ztmrmd00420 FROM TABLE @lt_hist.
    ENDIF.

    " [수정 #3] 물리 삭제가 없어져서 delete-matsup 처리 제거
    "  (D는 SaveAll/PATCH에서 삭제지시자 update로 들어와 위 update-matsup에서 처리됨)
  ENDMETHOD.

ENDCLASS.
