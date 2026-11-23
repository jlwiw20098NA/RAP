*"* Local Types of ZBP_MRMD_R_MATSUPDEMMASTERSAVE
*"* - lhc_matsup : SaveAll로 행마다 Status(C/U/D)에 따라 00410 처리
*"* - lsc_matsup : 같은 트랜잭션에서 00420(이력) 저장 (with additional save)
*"* 하나라도 실패하면 00410, 00420 모두 저장되지 않음

CLASS lhc_matsup DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    CONSTANTS: BEGIN OF c_status,
                 create TYPE c LENGTH 1 VALUE 'C',
                 update TYPE c LENGTH 1 VALUE 'U',
                 delete TYPE c LENGTH 1 VALUE 'D',
               END OF c_status.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR MatSup RESULT result.

    " [수정 #1] 생성/변경 일시·사용자
    METHODS setCreateStamp FOR DETERMINE ON SAVE
      IMPORTING keys FOR MatSup~setCreateStamp.
    METHODS setChangeStamp FOR DETERMINE ON SAVE
      IMPORTING keys FOR MatSup~setChangeStamp.

    METHODS SaveAll FOR MODIFY
      IMPORTING keys FOR ACTION MatSup~SaveAll.
ENDCLASS.


CLASS lhc_matsup IMPLEMENTATION.

  METHOD get_global_authorizations.
    " create/update/delete는 internal이라 action 권한만 판단
    result = VALUE #( %action-SaveAll = if_abap_behv=>auth-allowed ).
  ENDMETHOD.


  METHOD SaveAll.
    DATA: lt_read      TYPE TABLE FOR READ IMPORT zmrmd_r_matsupdemmastersave\\matsup,
          lt_db        TYPE TABLE FOR READ RESULT zmrmd_r_matsupdemmastersave\\matsup,
          lt_create    TYPE TABLE FOR CREATE zmrmd_r_matsupdemmastersave\\matsup,
          lt_update    TYPE TABLE FOR UPDATE zmrmd_r_matsupdemmastersave\\matsup,
          lt_delete    TYPE TABLE FOR DELETE zmrmd_r_matsupdemmastersave\\matsup,
          ls_failed    TYPE RESPONSE FOR FAILED EARLY zmrmd_r_matsupdemmastersave,
          ls_reported  TYPE RESPONSE FOR REPORTED EARLY zmrmd_r_matsupdemmastersave,
          lt_msg       TYPE string_table,
          lv_idx       TYPE i,
          lv_row_error TYPE abap_boolean,
          lv_found     TYPE abap_boolean.

    LOOP AT keys INTO DATA(ls_key).
      CLEAR: lt_read, lt_db, lt_create, lt_update, lt_delete,
             ls_failed, ls_reported, lt_msg.

      DATA(lt_in) = ls_key-%param-_Row.

      " Status는 대문자로 통일 (c/u/d로 와도 처리)
      LOOP AT lt_in ASSIGNING FIELD-SYMBOL(<ls_in>).
        <ls_in>-Status = to_upper( <ls_in>-Status ).
      ENDLOOP.

      IF lt_in IS INITIAL.
        APPEND `저장할 데이터가 없습니다` TO lt_msg.
      ENDIF.

      "==============================================================
      " 0. payload 안 키 중복 확인 (CompanyCode, Material, Supplier, GoodsSupplier)
      "==============================================================
      DATA(lt_dup) = lt_in.
      SORT lt_dup BY CompanyCode Material Supplier GoodsSupplier.
      DELETE ADJACENT DUPLICATES FROM lt_dup COMPARING CompanyCode Material Supplier GoodsSupplier.
      IF lines( lt_dup ) <> lines( lt_in ).
        APPEND `같은 키(회사코드/자재/공급업체/물품공급업체)가 중복으로 들어왔습니다` TO lt_msg.
      ENDIF.

      "==============================================================
      " 1. 기존 데이터 조회 (DB + 트랜잭션 버퍼)
      "==============================================================
      lt_read = VALUE #( FOR r IN lt_in
                         ( CompanyCode   = r-CompanyCode
                           Material      = r-Material
                           Supplier      = r-Supplier
                           GoodsSupplier = r-GoodsSupplier ) ).
      IF lt_read IS NOT INITIAL.
        READ ENTITIES OF zmrmd_r_matsupdemmastersave IN LOCAL MODE
          ENTITY MatSup
          FIELDS ( SupplyRatio Remark )
          WITH lt_read
          RESULT lt_db.
      ENDIF.

      "==============================================================
      " 2. 행 처리
      "==============================================================
      LOOP AT lt_in INTO DATA(ls_in).
        lv_idx = sy-tabix.
        CLEAR lv_row_error.

        "------------------------------------------------------------
        " 2-1. 필수 입력 체크 (모든 Status: 키로 대상을 찾아야 하므로)
        "------------------------------------------------------------
        IF ls_in-CompanyCode IS INITIAL.
          APPEND |{ lv_idx }번째 행: [CompanyCode] is required.| TO lt_msg.
          lv_row_error = abap_true.
        ENDIF.
        IF ls_in-Material IS INITIAL.
          APPEND |{ lv_idx }번째 행: [Material] is required.| TO lt_msg.
          lv_row_error = abap_true.
        ENDIF.
        IF ls_in-Supplier IS INITIAL.
          APPEND |{ lv_idx }번째 행: [Supplier] is required.| TO lt_msg.
          lv_row_error = abap_true.
        ENDIF.
        IF ls_in-GoodsSupplier IS INITIAL.
          APPEND |{ lv_idx }번째 행: [GoodsSupplier] is required.| TO lt_msg.
          lv_row_error = abap_true.
        ENDIF.
        IF lv_row_error = abap_true.
          CONTINUE.
        ENDIF.

        DATA(lv_exists) = xsdbool( line_exists(
          lt_db[ KEY id COMPONENTS CompanyCode   = ls_in-CompanyCode
                                   Material      = ls_in-Material
                                   Supplier      = ls_in-Supplier
                                   GoodsSupplier = ls_in-GoodsSupplier ] ) ).

        CASE ls_in-Status.

          "----------------------------------------------------------
          " C: 생성 (중복 체크 + 유효성 체크)
          "----------------------------------------------------------
          WHEN c_status-create.
            " 중복 데이터 체크 (00410 키 기준)
            IF lv_exists = abap_true.
              APPEND |{ lv_idx }번째 행: 이미 등록된 데이터입니다 | &&
                     |({ ls_in-CompanyCode }/{ ls_in-Material }/{ ls_in-Supplier }/{ ls_in-GoodsSupplier })| TO lt_msg.
              CONTINUE.
            ENDIF.

            " 유효성 체크: 회사코드 (I_CompanyCode)
            CLEAR lv_found.
            SELECT SINGLE @abap_true FROM I_CompanyCode
              WHERE CompanyCode = @ls_in-CompanyCode
              INTO @lv_found
              WITH PRIVILEGED ACCESS.
            IF lv_found = abap_false.
              APPEND |[CompanyCode] { ls_in-CompanyCode } does not exist.| TO lt_msg.
              lv_row_error = abap_true.
            ENDIF.

            " 유효성 체크: 자재 (I_Product)
            CLEAR lv_found.
            SELECT SINGLE @abap_true FROM I_Product
              WHERE Product = @ls_in-Material
              INTO @lv_found
              WITH PRIVILEGED ACCESS.
            IF lv_found = abap_false.
              APPEND |[Material] { ls_in-Material } does not exist.| TO lt_msg.
              lv_row_error = abap_true.
            ENDIF.

            " 유효성 체크: 공급업체 (I_Supplier)
            CLEAR lv_found.
            SELECT SINGLE @abap_true FROM I_Supplier
              WHERE Supplier = @ls_in-Supplier
              INTO @lv_found
              WITH PRIVILEGED ACCESS.
            IF lv_found = abap_false.
              APPEND |[Supplier] { ls_in-Supplier } does not exist.| TO lt_msg.
              lv_row_error = abap_true.
            ENDIF.

            " 유효성 체크: 물품공급업체 (I_Supplier)
            CLEAR lv_found.
            SELECT SINGLE @abap_true FROM I_Supplier
              WHERE Supplier = @ls_in-GoodsSupplier
              INTO @lv_found
              WITH PRIVILEGED ACCESS.
            IF lv_found = abap_false.
              APPEND |[GoodsSupplier] { ls_in-GoodsSupplier } does not exist.| TO lt_msg.
              lv_row_error = abap_true.
            ENDIF.

            IF lv_row_error = abap_true.
              CONTINUE.
            ENDIF.

            APPEND VALUE #( %cid          = |ROW{ lv_idx }|
                            CompanyCode   = ls_in-CompanyCode
                            Material      = ls_in-Material
                            Supplier      = ls_in-Supplier
                            GoodsSupplier = ls_in-GoodsSupplier
                            SupplyRatio   = ls_in-SupplyRatio
                            Remark        = ls_in-Remark ) TO lt_create.

          "----------------------------------------------------------
          " U: 수정 (SupplyRatio, Remark만)
          "----------------------------------------------------------
          WHEN c_status-update.
            IF lv_exists = abap_false.
              APPEND |{ lv_idx }번째 행: 수정할 데이터가 없습니다 | &&
                     |({ ls_in-CompanyCode }/{ ls_in-Material }/{ ls_in-Supplier }/{ ls_in-GoodsSupplier })| TO lt_msg.
              CONTINUE.
            ENDIF.
            APPEND VALUE #( CompanyCode   = ls_in-CompanyCode
                            Material      = ls_in-Material
                            Supplier      = ls_in-Supplier
                            GoodsSupplier = ls_in-GoodsSupplier
                            SupplyRatio   = ls_in-SupplyRatio
                            Remark        = ls_in-Remark ) TO lt_update.

          "----------------------------------------------------------
          " D: 삭제
          "----------------------------------------------------------
          WHEN c_status-delete.
            IF lv_exists = abap_false.
              APPEND |{ lv_idx }번째 행: 삭제할 데이터가 없습니다 | &&
                     |({ ls_in-CompanyCode }/{ ls_in-Material }/{ ls_in-Supplier }/{ ls_in-GoodsSupplier })| TO lt_msg.
              CONTINUE.
            ENDIF.
            APPEND VALUE #( CompanyCode   = ls_in-CompanyCode
                            Material      = ls_in-Material
                            Supplier      = ls_in-Supplier
                            GoodsSupplier = ls_in-GoodsSupplier ) TO lt_delete.

          WHEN OTHERS.
            APPEND |{ lv_idx }번째 행: Status '{ ls_in-Status }'는 허용되지 않습니다 (C/U/D)| TO lt_msg.
        ENDCASE.
      ENDLOOP.

      "==============================================================
      " 3. 사전 체크 오류가 있으면 아무것도 바꾸지 않고 실패
      "==============================================================
      IF lt_msg IS NOT INITIAL.
        APPEND VALUE #( %cid = ls_key-%cid ) TO failed-matsup.
        LOOP AT lt_msg INTO DATA(lv_text).
          APPEND VALUE #( %cid = ls_key-%cid
                          %msg = new_message_with_text(
                                   severity = if_abap_behv_message=>severity-error
                                   text     = lv_text ) ) TO reported-matsup.
        ENDLOOP.
        CONTINUE.
      ENDIF.

      "==============================================================
      " 4. EML 실행 (00410은 managed가 저장, 00420은 saver의 save_modified가 저장)
      "==============================================================
      IF lt_create IS NOT INITIAL OR lt_update IS NOT INITIAL OR lt_delete IS NOT INITIAL.
        MODIFY ENTITIES OF zmrmd_r_matsupdemmastersave IN LOCAL MODE
          ENTITY MatSup
            CREATE FIELDS ( CompanyCode Material Supplier GoodsSupplier SupplyRatio Remark )
              WITH lt_create
            UPDATE FIELDS ( SupplyRatio Remark )
              WITH lt_update
            DELETE FROM lt_delete
          FAILED ls_failed
          REPORTED ls_reported.

        IF ls_failed-matsup IS NOT INITIAL.
          APPEND VALUE #( %cid = ls_key-%cid ) TO failed-matsup.
        ENDIF.
        LOOP AT ls_reported-matsup INTO DATA(ls_rep).
          APPEND VALUE #( %cid = ls_key-%cid %msg = ls_rep-%msg ) TO reported-matsup.
        ENDLOOP.
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

ENDCLASS.


CLASS lsc_matsup DEFINITION INHERITING FROM cl_abap_behavior_saver.
  PROTECTED SECTION.
    METHODS save_modified REDEFINITION.
ENDCLASS.


CLASS lsc_matsup IMPLEMENTATION.

  METHOD save_modified.
    "================================================================
    " 00420 저장 (00410 저장과 같은 트랜잭션 → COMMIT은 프레임워크가 함)
    "  C/U: 최종 상태를 로그 행으로 INSERT (TimeStamp = 저장 시각, UTC)   [수정 #2]
    "  D: 삭제지시자 공백인 로그 행에 'X' (변경 없음)
    "  ※ 이 단계는 실패시킬 수 없으므로 검증은 모두 SaveAll에서 끝냄
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
                           del_ind      = space ) ).

      INSERT ztmrmd00420 FROM TABLE @lt_hist.
    ENDIF.

    " D: 삭제지시자 'X'
    " [수정 #1] 삭제는 키만 넘어오므로 삭제 시각·사용자를 여기서 구해서 변경 일시에 기록
    DATA(lv_del_date) = cl_abap_context_info=>get_system_date( ).
    DATA(lv_del_time) = cl_abap_context_info=>get_system_time( ).
    DATA(lv_del_user) = cl_abap_context_info=>get_user_technical_name( ).

    LOOP AT delete-matsup INTO DATA(ls_d).
      UPDATE ztmrmd00420
        SET del_ind = 'X',
            aedat   = @lv_del_date,      " [수정 #1]
            aezet   = @lv_del_time,      " [수정 #1]
            aenam   = @lv_del_user       " [수정 #1]
        WHERE bukrs       = @ls_d-CompanyCode
          AND matnr       = @ls_d-Material
          AND lifnr       = @ls_d-Supplier
          AND goods_lifnr = @ls_d-GoodsSupplier
          AND del_ind     = @space.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
