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
ENDCLASS.


CLASS lhc_matsup IMPLEMENTATION.

  METHOD get_global_authorizations.
    result = VALUE #( %create = if_abap_behv=>auth-allowed
                      %update = if_abap_behv=>auth-allowed
                      %delete = if_abap_behv=>auth-allowed ).
  ENDMETHOD.


  METHOD validateOnCreate.
    DATA: lv_error TYPE abap_boolean,
          lv_found TYPE abap_boolean.

    READ ENTITIES OF zmrmd_r_matsupdemmastersave IN LOCAL MODE
      ENTITY MatSup
      FIELDS ( CompanyCode Material Supplier GoodsSupplier )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_rows).

    LOOP AT lt_rows INTO DATA(ls).
      CLEAR lv_error.

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
      CLEAR lv_found.
      SELECT SINGLE @abap_true FROM zmrmd_i_ztmrmd00410
        WHERE CompanyCode   = @ls-CompanyCode
          AND Material      = @ls-Material
          AND Supplier      = @ls-Supplier
          AND GoodsSupplier = @ls-GoodsSupplier
        INTO @lv_found.
      IF lv_found = abap_true.
        APPEND VALUE #( %tky = ls-%tky
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = |이미 등록된 데이터입니다 | &&
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

ENDCLASS.


CLASS lsc_matsup DEFINITION INHERITING FROM cl_abap_behavior_saver.
  PROTECTED SECTION.
    METHODS save_modified REDEFINITION.
ENDCLASS.


CLASS lsc_matsup IMPLEMENTATION.

  METHOD save_modified.
    "================================================================
    " 00420 저장 (SaveAll 버전과 동일)
    "  C: 행 생성 (TimeStamp = 저장 시각, UTC)
    "  U: 유효한 행(삭제지시자 공백)의 SupplyRatio / Remark 수정 (바뀐 필드만)
    "  D: 유효한 행에 삭제지시자 'X'
    "  생성/변경 일시·사용자(ERDAT/ERZET/ERNAM, AEDAT/AEZET/AENAM)도 함께 기록   [수정 #1]
    "  TODO: 테이블명(ztmrmd00420)과 컬럼명을 실제 값으로 맞추세요
    "================================================================
    DATA lt_hist TYPE STANDARD TABLE OF ztmrmd00420 WITH EMPTY KEY.
    DATA lv_ts   TYPE tzntstmps.

    GET TIME STAMP FIELD lv_ts.

    IF create-matsup IS NOT INITIAL.
      lt_hist = VALUE #( FOR c IN create-matsup
                         ( bukrs        = c-CompanyCode
                           matnr        = c-Material
                           lifnr        = c-Supplier
                           goods_lifnr  = c-GoodsSupplier
                           time_stamp   = lv_ts
                           supply_ratio = c-SupplyRatio
                           remark       = c-Remark
                           erdat        = c-CreatedDate     " [수정 #1] determination이 채운 값
                           erzet        = c-CreatedTime
                           ernam        = c-CreatedBy
                           aedat        = c-ChangedDate
                           aezet        = c-ChangedTime
                           aenam        = c-ChangedBy
                           del_ind      = space ) ).
      INSERT ztmrmd00420 FROM TABLE @lt_hist.
    ENDIF.

    LOOP AT update-matsup INTO DATA(ls_u).
      IF ls_u-%control-SupplyRatio = if_abap_behv=>mk-on.
        UPDATE ztmrmd00420
          SET supply_ratio = @ls_u-SupplyRatio
          WHERE bukrs       = @ls_u-CompanyCode
            AND matnr       = @ls_u-Material
            AND lifnr       = @ls_u-Supplier
            AND goods_lifnr = @ls_u-GoodsSupplier
            AND del_ind     = @space.
      ENDIF.
      IF ls_u-%control-Remark = if_abap_behv=>mk-on.
        UPDATE ztmrmd00420
          SET remark = @ls_u-Remark
          WHERE bukrs       = @ls_u-CompanyCode
            AND matnr       = @ls_u-Material
            AND lifnr       = @ls_u-Supplier
            AND goods_lifnr = @ls_u-GoodsSupplier
            AND del_ind     = @space.
      ENDIF.
      " [수정 #1] 변경 일시·사용자 (setChangeStamp가 채운 값)
      IF ls_u-%control-ChangedDate = if_abap_behv=>mk-on.
        UPDATE ztmrmd00420
          SET aedat = @ls_u-ChangedDate,
              aezet = @ls_u-ChangedTime,
              aenam = @ls_u-ChangedBy
          WHERE bukrs       = @ls_u-CompanyCode
            AND matnr       = @ls_u-Material
            AND lifnr       = @ls_u-Supplier
            AND goods_lifnr = @ls_u-GoodsSupplier
            AND del_ind     = @space.
      ENDIF.
    ENDLOOP.

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
