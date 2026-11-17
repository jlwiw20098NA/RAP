*"* Local Types of ZBP_MRMD_R_DTLITEMMNG
*"* SaveAll 하나로 Mng/User 행을 Status(C/U/D)에 따라 처리
*"* 같은 BO(composition)라서 한 LUW: 하나라도 실패하면 전체 롤백

CLASS lhc_mng DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    CONSTANTS: BEGIN OF c_status,
                 create TYPE c LENGTH 1 VALUE 'C',
                 update TYPE c LENGTH 1 VALUE 'U',
                 delete TYPE c LENGTH 1 VALUE 'D',
               END OF c_status.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR Mng RESULT result.

    METHODS SaveAll FOR MODIFY
      IMPORTING keys FOR ACTION Mng~SaveAll.

    METHODS setCreateStamp FOR DETERMINE ON SAVE
      IMPORTING keys FOR Mng~setCreateStamp.

    METHODS setChangeStamp FOR DETERMINE ON SAVE
      IMPORTING keys FOR Mng~setChangeStamp.

    " [수정 #1] collect_result 헬퍼 메서드 제거
    "  기존: 파라미터를 TYPE RESPONSE FOR FAILED/REPORTED EARLY ... 로 선언 → "Unable to interpret Failed"
    "  변경: 같은 로직을 SaveAll 안에 직접 작성 (5단계 EML 결과 처리)
ENDCLASS.


CLASS lhc_mng IMPLEMENTATION.

  METHOD get_global_authorizations.
    " create/update/delete는 internal이라 action 권한만 판단
    result = VALUE #( %action-SaveAll = if_abap_behv=>auth-allowed ).
  ENDMETHOD.


  METHOD SaveAll.
    DATA: lt_mng_read   TYPE TABLE FOR READ IMPORT zmrmd_r_dtlitemmng\\mng,
          lt_mng_db     TYPE TABLE FOR READ RESULT zmrmd_r_dtlitemmng\\mng,
          lt_usr_read   TYPE TABLE FOR READ IMPORT zmrmd_r_dtlitemmng\\user,
          lt_usr_db     TYPE TABLE FOR READ RESULT zmrmd_r_dtlitemmng\\user,
          lt_chd_read   TYPE TABLE FOR READ IMPORT zmrmd_r_dtlitemmng\\mng\_user,
          lt_chd_db     TYPE TABLE FOR READ RESULT zmrmd_r_dtlitemmng\\mng\_user,
          lt_mng_create TYPE TABLE FOR CREATE zmrmd_r_dtlitemmng\\mng,
          lt_mng_update TYPE TABLE FOR UPDATE zmrmd_r_dtlitemmng\\mng,
          lt_mng_delete TYPE TABLE FOR DELETE zmrmd_r_dtlitemmng\\mng,
          lt_usr_create TYPE TABLE FOR CREATE zmrmd_r_dtlitemmng\\mng\_user,
          lt_usr_delete TYPE TABLE FOR DELETE zmrmd_r_dtlitemmng\\user,
          ls_failed     TYPE RESPONSE FOR FAILED EARLY zmrmd_r_dtlitemmng,
          ls_reported   TYPE RESPONSE FOR REPORTED EARLY zmrmd_r_dtlitemmng,
          lt_msg        TYPE string_table,
          lv_idx        TYPE i,
          lv_has_child  TYPE abap_boolean,
          lv_eml_error  TYPE abap_boolean,
          lv_igc_valid  TYPE abap_boolean.   " [수정 #2] ItemGroupCode 공통코드 체크 결과

    LOOP AT keys INTO DATA(ls_key).
      CLEAR: lt_mng_read, lt_mng_db, lt_usr_read, lt_usr_db, lt_chd_read, lt_chd_db,
             lt_mng_create, lt_mng_update, lt_mng_delete, lt_usr_create, lt_usr_delete,
             ls_failed, ls_reported, lt_msg, lv_eml_error.

      DATA(lt_mng_in) = ls_key-%param-_Mng.
      DATA(lt_usr_in) = ls_key-%param-_User.

      " Status는 대문자로 통일 (c/u/d로 와도 처리)
      LOOP AT lt_mng_in ASSIGNING FIELD-SYMBOL(<ls_m>).
        <ls_m>-Status = to_upper( <ls_m>-Status ).
      ENDLOOP.
      LOOP AT lt_usr_in ASSIGNING FIELD-SYMBOL(<ls_u>).
        <ls_u>-Status = to_upper( <ls_u>-Status ).
      ENDLOOP.

      IF lt_mng_in IS INITIAL AND lt_usr_in IS INITIAL.
        APPEND `저장할 데이터가 없습니다` TO lt_msg.
      ENDIF.

      "==============================================================
      " 0. payload 안 키 중복 확인
      "==============================================================
      DATA(lt_dup_m) = lt_mng_in.
      SORT lt_dup_m BY CompanyCode ItemGroupCode DetailedItemGroupCode.
      DELETE ADJACENT DUPLICATES FROM lt_dup_m
             COMPARING CompanyCode ItemGroupCode DetailedItemGroupCode.
      IF lines( lt_dup_m ) <> lines( lt_mng_in ).
        APPEND `같은 세부품목그룹이 중복으로 들어왔습니다` TO lt_msg.
      ENDIF.

      DATA(lt_dup_u) = lt_usr_in.
      SORT lt_dup_u BY CompanyCode ItemGroupCode DetailedItemGroupCode UserID.
      DELETE ADJACENT DUPLICATES FROM lt_dup_u
             COMPARING CompanyCode ItemGroupCode DetailedItemGroupCode UserID.
      IF lines( lt_dup_u ) <> lines( lt_usr_in ).
        APPEND `같은 담당자가 중복으로 들어왔습니다` TO lt_msg.
      ENDIF.

      "==============================================================
      " 1. 기존 데이터 조회 (DB + 트랜잭션 버퍼)
      "==============================================================
      " 1-1. Mng: Mng 행 + User 행의 상위 키
      lt_mng_read = VALUE #( FOR m IN lt_mng_in
                             ( CompanyCode           = m-CompanyCode
                               ItemGroupCode         = m-ItemGroupCode
                               DetailedItemGroupCode = m-DetailedItemGroupCode ) ).
      lt_mng_read = VALUE #( BASE lt_mng_read
                             FOR u IN lt_usr_in
                             ( CompanyCode           = u-CompanyCode
                               ItemGroupCode         = u-ItemGroupCode
                               DetailedItemGroupCode = u-DetailedItemGroupCode ) ).
      SORT lt_mng_read BY CompanyCode ItemGroupCode DetailedItemGroupCode.
      DELETE ADJACENT DUPLICATES FROM lt_mng_read
             COMPARING CompanyCode ItemGroupCode DetailedItemGroupCode.

      IF lt_mng_read IS NOT INITIAL.
        READ ENTITIES OF zmrmd_r_dtlitemmng IN LOCAL MODE
          ENTITY Mng
          FIELDS ( DetailedItemGroupName )
          WITH lt_mng_read
          RESULT lt_mng_db.
      ENDIF.

      " 1-2. User: User 행
      lt_usr_read = VALUE #( FOR u IN lt_usr_in
                             ( CompanyCode           = u-CompanyCode
                               ItemGroupCode         = u-ItemGroupCode
                               DetailedItemGroupCode = u-DetailedItemGroupCode
                               UserID                = u-UserID ) ).
      IF lt_usr_read IS NOT INITIAL.
        READ ENTITIES OF zmrmd_r_dtlitemmng IN LOCAL MODE
          ENTITY User
          FIELDS ( UserID )
          WITH lt_usr_read
          RESULT lt_usr_db.
      ENDIF.

      " 1-3. 삭제 대상 Mng의 하위 User
      lt_chd_read = VALUE #( FOR m IN lt_mng_in WHERE ( Status = c_status-delete )
                             ( CompanyCode           = m-CompanyCode
                               ItemGroupCode         = m-ItemGroupCode
                               DetailedItemGroupCode = m-DetailedItemGroupCode ) ).
      IF lt_chd_read IS NOT INITIAL.
        READ ENTITIES OF zmrmd_r_dtlitemmng IN LOCAL MODE
          ENTITY Mng BY \_User
          FIELDS ( UserID )
          WITH lt_chd_read
          RESULT lt_chd_db.
      ENDIF.

      "==============================================================
      " 2. Mng 행 처리
      "==============================================================
      LOOP AT lt_mng_in INTO DATA(ls_m).
        lv_idx = sy-tabix.
        DATA(lv_m_exists) = xsdbool( line_exists(
          lt_mng_db[ KEY id COMPONENTS CompanyCode           = ls_m-CompanyCode
                                       ItemGroupCode         = ls_m-ItemGroupCode
                                       DetailedItemGroupCode = ls_m-DetailedItemGroupCode ] ) ).

        CASE ls_m-Status.

          WHEN c_status-create.
            IF lv_m_exists = abap_true.
              APPEND |세부품목그룹 { lv_idx }번째: { ls_m-DetailedItemGroupCode }는 이미 존재합니다| TO lt_msg.
            ELSE.
              "▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼
              " [유효성 체크 #1] ItemGroupCode 공통코드 체크   ← [수정 #2] 2026-11-17 구현
              "  공통코드(ZMRMD_I_ZTMRMD00740)에서
              "  CodeClass = 'PQMD1010', UsedCheck = 'X', Attribute03 = 'SUB',
              "  Attribute04 = 회사코드, Attribute041 = 품목그룹코드 인 행이 있어야 함
              CLEAR lv_igc_valid.   " SELECT SINGLE은 못 찾으면 값을 안 바꾸므로 매 행 초기화
              SELECT SINGLE @abap_true
                FROM zmrmd_i_ztmrmd00740
                WHERE CodeClass    = 'PQMD1010'
                  AND UsedCheck    = 'X'
                  AND Attribute03  = 'SUB'
                  AND Attribute04  = @ls_m-CompanyCode
                  AND Attribute041 = @ls_m-ItemGroupCode
                INTO @lv_igc_valid.

              IF lv_igc_valid = abap_false.
                APPEND |[ItemGroupCode] { ls_m-ItemGroupCode } does not exist.| TO lt_msg.
                CONTINUE.   " 생성 대상에 넣지 않고 다음 Mng 행으로
              ENDIF.
              "▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲

              "▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼
              " [유효성 체크 위치 #2] DetailedItemGroupCode
              "  - ls_m-DetailedItemGroupCode 형식/허용값 확인 (예: 도메인 고정값, 코드 규칙)
              "  - 실패 시: APPEND |세부품목그룹 { lv_idx }번째: 세부품목그룹코드
              "             { ls_m-DetailedItemGroupCode }가 유효하지 않습니다| TO lt_msg.
              "             그리고 아래 APPEND(생성 대상 추가)는 건너뜀
              "▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲

              APPEND VALUE #( %cid                  = |MNG{ lv_idx }|
                              CompanyCode           = ls_m-CompanyCode
                              ItemGroupCode         = ls_m-ItemGroupCode
                              DetailedItemGroupCode = ls_m-DetailedItemGroupCode
                              DetailedItemGroupName = ls_m-DetailedItemGroupName
                              Remark                = ls_m-Remark ) TO lt_mng_create.
            ENDIF.

          WHEN c_status-update.
            " 수정 대상: 품목명, Remark만
            IF lv_m_exists = abap_false.
              APPEND |세부품목그룹 { lv_idx }번째: { ls_m-DetailedItemGroupCode }가 존재하지 않아 수정할 수 없습니다| TO lt_msg.
            ELSE.
              APPEND VALUE #( CompanyCode           = ls_m-CompanyCode
                              ItemGroupCode         = ls_m-ItemGroupCode
                              DetailedItemGroupCode = ls_m-DetailedItemGroupCode
                              DetailedItemGroupName = ls_m-DetailedItemGroupName
                              Remark                = ls_m-Remark ) TO lt_mng_update.
            ENDIF.

          WHEN c_status-delete.
            IF lv_m_exists = abap_false.
              APPEND |세부품목그룹 { lv_idx }번째: { ls_m-DetailedItemGroupCode }가 존재하지 않아 삭제할 수 없습니다| TO lt_msg.
            ELSE.
              " 하위 User가 남으면 삭제 금지
              " - DB의 하위 중 이번 요청에서 D로 같이 지우지 않는 것이 하나라도 있으면 막음
              " - 같은 요청에서 이 Mng 아래로 User를 C로 추가하려는 경우도 막음
              CLEAR lv_has_child.
              LOOP AT lt_chd_db INTO DATA(ls_chd)
                   WHERE CompanyCode           = ls_m-CompanyCode
                     AND ItemGroupCode         = ls_m-ItemGroupCode
                     AND DetailedItemGroupCode = ls_m-DetailedItemGroupCode.
                IF NOT line_exists( lt_usr_in[ Status                = c_status-delete
                                               CompanyCode           = ls_chd-CompanyCode
                                               ItemGroupCode         = ls_chd-ItemGroupCode
                                               DetailedItemGroupCode = ls_chd-DetailedItemGroupCode
                                               UserID                = ls_chd-UserID ] ).
                  lv_has_child = abap_true.
                  EXIT.
                ENDIF.
              ENDLOOP.
              IF line_exists( lt_usr_in[ Status                = c_status-create
                                         CompanyCode           = ls_m-CompanyCode
                                         ItemGroupCode         = ls_m-ItemGroupCode
                                         DetailedItemGroupCode = ls_m-DetailedItemGroupCode ] ).
                lv_has_child = abap_true.
              ENDIF.

              IF lv_has_child = abap_true.
                APPEND |세부품목그룹 { ls_m-DetailedItemGroupCode }에 담당자가 있어 삭제할 수 없습니다| TO lt_msg.
              ELSE.
                APPEND VALUE #( CompanyCode           = ls_m-CompanyCode
                                ItemGroupCode         = ls_m-ItemGroupCode
                                DetailedItemGroupCode = ls_m-DetailedItemGroupCode ) TO lt_mng_delete.
              ENDIF.
            ENDIF.

          WHEN OTHERS.
            APPEND |세부품목그룹 { lv_idx }번째: Status '{ ls_m-Status }'는 허용되지 않습니다 (C/U/D)| TO lt_msg.
        ENDCASE.
      ENDLOOP.

      "==============================================================
      " 3. User 행 처리 (생성/삭제만. 사번은 키라 수정 없음)
      "==============================================================
      LOOP AT lt_usr_in INTO DATA(ls_u).
        lv_idx = sy-tabix.

        DATA(lv_parent_db) = xsdbool( line_exists(
          lt_mng_db[ KEY id COMPONENTS CompanyCode           = ls_u-CompanyCode
                                       ItemGroupCode         = ls_u-ItemGroupCode
                                       DetailedItemGroupCode = ls_u-DetailedItemGroupCode ] ) ).
        DATA(lv_parent_new) = xsdbool( line_exists(
          lt_mng_in[ Status                = c_status-create
                     CompanyCode           = ls_u-CompanyCode
                     ItemGroupCode         = ls_u-ItemGroupCode
                     DetailedItemGroupCode = ls_u-DetailedItemGroupCode ] ) ).
        DATA(lv_u_exists) = xsdbool( line_exists(
          lt_usr_db[ KEY id COMPONENTS CompanyCode           = ls_u-CompanyCode
                                       ItemGroupCode         = ls_u-ItemGroupCode
                                       DetailedItemGroupCode = ls_u-DetailedItemGroupCode
                                       UserID                = ls_u-UserID ] ) ).

        CASE ls_u-Status.

          WHEN c_status-create.
            IF lv_parent_db = abap_false AND lv_parent_new = abap_false.
              APPEND |담당자 { lv_idx }번째: 상위 세부품목그룹 { ls_u-DetailedItemGroupCode }가 없습니다| TO lt_msg.
            ELSEIF lv_u_exists = abap_true.
              APPEND |담당자 { lv_idx }번째: { ls_u-UserID }는 이미 등록되어 있습니다| TO lt_msg.
            ELSE.
              "▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼
              " [유효성 체크 위치 #3] UserID (담당자 사번)
              "  - ls_u-UserID 가 유효한 사번/사용자인지 확인 (예: 사용자 마스터, 인사 데이터)
              "  - 실패 시: APPEND |담당자 { lv_idx }번째: 사번 { ls_u-UserID }가
              "             유효하지 않습니다| TO lt_msg.  그리고 아래 생성 대상 추가는 건너뜀
              "▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲

              " 상위별로 생성 항목 하나를 만들고, 그 %target에 담당자를 추가
              IF lv_parent_new = abap_true.
                " 같은 요청에서 생성되는 Mng 아래 -> %cid_ref로 연결
                DATA(lv_ref) = VALUE #( lt_mng_create[ CompanyCode           = ls_u-CompanyCode
                                                       ItemGroupCode         = ls_u-ItemGroupCode
                                                       DetailedItemGroupCode = ls_u-DetailedItemGroupCode ]-%cid OPTIONAL ).
                IF lv_ref IS INITIAL.
                  CONTINUE.   " 상위 Mng 생성이 이미 오류 처리된 경우
                ENDIF.
                READ TABLE lt_usr_create ASSIGNING FIELD-SYMBOL(<ls_uc>) WITH KEY %cid_ref = lv_ref.
                IF sy-subrc <> 0.
                  APPEND VALUE #( %cid_ref = lv_ref ) TO lt_usr_create ASSIGNING <ls_uc>.
                ENDIF.
              ELSE.
                " 기존 Mng 아래 -> 상위 키로 연결
                READ TABLE lt_usr_create ASSIGNING <ls_uc>
                     WITH KEY %cid_ref             = ''
                              CompanyCode           = ls_u-CompanyCode
                              ItemGroupCode         = ls_u-ItemGroupCode
                              DetailedItemGroupCode = ls_u-DetailedItemGroupCode.
                IF sy-subrc <> 0.
                  APPEND VALUE #( CompanyCode           = ls_u-CompanyCode
                                  ItemGroupCode         = ls_u-ItemGroupCode
                                  DetailedItemGroupCode = ls_u-DetailedItemGroupCode ) TO lt_usr_create ASSIGNING <ls_uc>.
                ENDIF.
              ENDIF.
              APPEND VALUE #( %cid   = |USR{ lv_idx }|
                              UserID = ls_u-UserID ) TO <ls_uc>-%target.
            ENDIF.

          WHEN c_status-delete.
            " 조건 없이 삭제. DB에 없으면 지울 대상이 없으므로 그냥 넘어감
            IF lv_u_exists = abap_true.
              APPEND VALUE #( CompanyCode           = ls_u-CompanyCode
                              ItemGroupCode         = ls_u-ItemGroupCode
                              DetailedItemGroupCode = ls_u-DetailedItemGroupCode
                              UserID                = ls_u-UserID ) TO lt_usr_delete.
            ENDIF.

          WHEN c_status-update.
            APPEND |담당자 { lv_idx }번째: 사번은 수정할 수 없습니다 (삭제 후 생성하세요)| TO lt_msg.

          WHEN OTHERS.
            APPEND |담당자 { lv_idx }번째: Status '{ ls_u-Status }'는 허용되지 않습니다 (C/D)| TO lt_msg.
        ENDCASE.
      ENDLOOP.

      "==============================================================
      " 4. 사전 체크 오류가 있으면 아무것도 바꾸지 않고 실패
      "==============================================================
      IF lt_msg IS NOT INITIAL.
        APPEND VALUE #( %cid = ls_key-%cid ) TO failed-mng.
        LOOP AT lt_msg INTO DATA(lv_text).
          APPEND VALUE #( %cid = ls_key-%cid
                          %msg = new_message_with_text(
                                   severity = if_abap_behv_message=>severity-error
                                   text     = lv_text ) ) TO reported-mng.
        ENDLOOP.
        CONTINUE.
      ENDIF.

      "==============================================================
      " 5. EML 실행 (같은 BO → 같은 LUW, 실패 시 전체 롤백)
      "    순서: User 삭제 → Mng 생성·수정 + User 생성 → Mng 삭제
      "==============================================================
      " 5-1. User 삭제
      IF lt_usr_delete IS NOT INITIAL.
        MODIFY ENTITIES OF zmrmd_r_dtlitemmng IN LOCAL MODE
          ENTITY User
            DELETE FROM lt_usr_delete
          FAILED ls_failed
          REPORTED ls_reported.
        " [수정 #1] EML 결과를 action 결과로 옮김 (기존: collect_result 호출)
        IF ls_failed-mng IS NOT INITIAL OR ls_failed-user IS NOT INITIAL.
          lv_eml_error = abap_true.
          APPEND VALUE #( %cid = ls_key-%cid ) TO failed-mng.
        ENDIF.
        LOOP AT ls_reported-mng INTO DATA(ls_rm1).
          APPEND VALUE #( %cid = ls_key-%cid %msg = ls_rm1-%msg ) TO reported-mng.
        ENDLOOP.
        LOOP AT ls_reported-user INTO DATA(ls_ru1).
          APPEND VALUE #( %cid = ls_key-%cid %msg = ls_ru1-%msg ) TO reported-mng.
        ENDLOOP.
        IF lv_eml_error = abap_true.
          CONTINUE.
        ENDIF.
      ENDIF.

      " 5-2. Mng 생성·수정 + User 생성
      "      새 Mng 아래 User는 %cid_ref로 연결되므로 같은 MODIFY 문장 안에 있어야 함
      IF lt_mng_create IS NOT INITIAL OR lt_mng_update IS NOT INITIAL OR lt_usr_create IS NOT INITIAL.
        CLEAR: ls_failed, ls_reported.
        MODIFY ENTITIES OF zmrmd_r_dtlitemmng IN LOCAL MODE
          ENTITY Mng
            CREATE FIELDS ( CompanyCode ItemGroupCode DetailedItemGroupCode
                            DetailedItemGroupName Remark )
              WITH lt_mng_create
            UPDATE FIELDS ( DetailedItemGroupName Remark )
              WITH lt_mng_update
            CREATE BY \_User FIELDS ( UserID )
              WITH lt_usr_create
          FAILED ls_failed
          REPORTED ls_reported.
        " [수정 #1] EML 결과를 action 결과로 옮김 (기존: collect_result 호출)
        IF ls_failed-mng IS NOT INITIAL OR ls_failed-user IS NOT INITIAL.
          lv_eml_error = abap_true.
          APPEND VALUE #( %cid = ls_key-%cid ) TO failed-mng.
        ENDIF.
        LOOP AT ls_reported-mng INTO DATA(ls_rm2).
          APPEND VALUE #( %cid = ls_key-%cid %msg = ls_rm2-%msg ) TO reported-mng.
        ENDLOOP.
        LOOP AT ls_reported-user INTO DATA(ls_ru2).
          APPEND VALUE #( %cid = ls_key-%cid %msg = ls_ru2-%msg ) TO reported-mng.
        ENDLOOP.
        IF lv_eml_error = abap_true.
          CONTINUE.
        ENDIF.
      ENDIF.

      " 5-3. Mng 삭제 (하위 User 정리 후)
      IF lt_mng_delete IS NOT INITIAL.
        CLEAR: ls_failed, ls_reported.
        MODIFY ENTITIES OF zmrmd_r_dtlitemmng IN LOCAL MODE
          ENTITY Mng
            DELETE FROM lt_mng_delete
          FAILED ls_failed
          REPORTED ls_reported.
        " [수정 #1] EML 결과를 action 결과로 옮김 (기존: collect_result 호출)
        IF ls_failed-mng IS NOT INITIAL OR ls_failed-user IS NOT INITIAL.
          lv_eml_error = abap_true.
          APPEND VALUE #( %cid = ls_key-%cid ) TO failed-mng.
        ENDIF.
        LOOP AT ls_reported-mng INTO DATA(ls_rm3).
          APPEND VALUE #( %cid = ls_key-%cid %msg = ls_rm3-%msg ) TO reported-mng.
        ENDLOOP.
        LOOP AT ls_reported-user INTO DATA(ls_ru3).
          APPEND VALUE #( %cid = ls_key-%cid %msg = ls_ru3-%msg ) TO reported-mng.
        ENDLOOP.
      ENDIF.
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
    METHODS setCreateStamp FOR DETERMINE ON SAVE
      IMPORTING keys FOR User~setCreateStamp.
ENDCLASS.


CLASS lhc_user IMPLEMENTATION.

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
