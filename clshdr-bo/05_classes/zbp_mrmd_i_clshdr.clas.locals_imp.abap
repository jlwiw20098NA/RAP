*"* Local Types of ZBP_MRMD_I_CLSHDR

CLASS lhc_header DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR Header RESULT result.

    METHODS SaveAll FOR MODIFY
      IMPORTING keys FOR ACTION Header~SaveAll.

    METHODS setCreateStamp FOR DETERMINE ON SAVE
      IMPORTING keys FOR Header~setCreateStamp.

    METHODS setChangeStamp FOR DETERMINE ON SAVE
      IMPORTING keys FOR Header~setChangeStamp.

    METHODS validateCompanyCode FOR VALIDATE ON SAVE
      IMPORTING keys FOR Header~validateCompanyCode.
ENDCLASS.

CLASS lhc_header IMPLEMENTATION.

  METHOD get_global_authorizations.
    " 권한 체크가 필요하면 AUTHORITY-CHECK 결과를 반영
    result = VALUE #( %create         = if_abap_behv=>auth-allowed
                      %update         = if_abap_behv=>auth-allowed
                      %delete         = if_abap_behv=>auth-allowed
                      %action-SaveAll = if_abap_behv=>auth-allowed ).
  ENDMETHOD.


  METHOD SaveAll.
    "==================================================================
    " [수정 이력] 2026-11-13 변경 없는 헤더/아이템 건너뛰기
    "  #1 lt_itm_exist 선언을 메서드 상단으로 이동
    "  #2 헤더 조회 필드에 KiloUnit 추가 (값 비교용)
    "  #3 헤더: 값이 같으면 UPDATE 건너뜀
    "  #4 루프 회차마다 lt_itm_exist 초기화
    "  #5 아이템 조회 필드에 DetailedItemGroupCode 추가 (값 비교용)
    "  #6 READ TABLE에 보조 키 id 명시 (성능 경고 해소)
    "  #7 아이템: 값이 같으면 UPDATE에서 제외
    "==================================================================
    DATA: ls_hdr_failed   TYPE RESPONSE FOR FAILED EARLY zmrmd_i_clshdr,
          ls_hdr_reported TYPE RESPONSE FOR REPORTED EARLY zmrmd_i_clshdr,
          lt_itm_read     TYPE TABLE FOR READ IMPORT zmrmd_i_clsitm,
          lt_itm_exist    TYPE TABLE FOR READ RESULT zmrmd_i_clsitm,  " [수정 #1] 인라인 선언 → 상단 선언
          lt_itm_create   TYPE TABLE FOR CREATE zmrmd_i_clsitm,
          lt_itm_update   TYPE TABLE FOR UPDATE zmrmd_i_clsitm,
          lv_has_error    TYPE abap_boolean.

    LOOP AT keys INTO DATA(ls_key).
      DATA(ls_p) = ls_key-%param.
      CLEAR: ls_hdr_failed, ls_hdr_reported, lt_itm_read,
             lt_itm_create, lt_itm_update, lv_has_error.

      "------------------------------------------------------------
      " 0. payload 안 (Plant, Material) 중복 확인
      "------------------------------------------------------------
      DATA(lt_dupchk) = ls_p-_Item.
      SORT lt_dupchk BY Plant Material.
      DATA(lv_cnt) = lines( lt_dupchk ).
      DELETE ADJACENT DUPLICATES FROM lt_dupchk COMPARING Plant Material.
      IF lines( lt_dupchk ) <> lv_cnt.
        APPEND VALUE #( %cid = ls_key-%cid ) TO failed-header.
        APPEND VALUE #( %cid = ls_key-%cid
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = '같은 플랜트/자재가 중복으로 들어왔습니다' ) )
               TO reported-header.
        CONTINUE.
      ENDIF.

      "------------------------------------------------------------
      " 1. 헤더 (자기 BO -> IN LOCAL MODE)
      "    없음            -> 생성
      "    있음 + 값 변경  -> 수정
      "    있음 + 값 동일  -> 건너뜀 (변경일시/잠금 없이 아이템만 처리)
      "------------------------------------------------------------
      READ ENTITIES OF zmrmd_i_clshdr IN LOCAL MODE
        ENTITY Header
        " [수정 #2] 기존: FIELDS ( ItemGroupCode ) → KiloUnit 추가
        FIELDS ( ItemGroupCode KiloUnit )
        WITH VALUE #( ( CompanyCode          = ls_p-CompanyCode
                        ClassLevel1          = ls_p-ClassLevel1
                        ClassLevel2          = ls_p-ClassLevel2
                        ClassLevel3          = ls_p-ClassLevel3
                        ManufacturingProcess = ls_p-ManufacturingProcess ) )
        RESULT DATA(lt_hdr_exist).

      IF lt_hdr_exist IS INITIAL.
        MODIFY ENTITIES OF zmrmd_i_clshdr IN LOCAL MODE
          ENTITY Header
          CREATE FIELDS ( CompanyCode ClassLevel1 ClassLevel2 ClassLevel3
                          ManufacturingProcess ItemGroupCode KiloUnit )
          WITH VALUE #( ( %cid                 = |HDR_{ ls_key-%cid }|
                          CompanyCode          = ls_p-CompanyCode
                          ClassLevel1          = ls_p-ClassLevel1
                          ClassLevel2          = ls_p-ClassLevel2
                          ClassLevel3          = ls_p-ClassLevel3
                          ManufacturingProcess = ls_p-ManufacturingProcess
                          ItemGroupCode        = ls_p-ItemGroupCode
                          KiloUnit             = ls_p-KiloUnit ) )
          FAILED ls_hdr_failed
          REPORTED ls_hdr_reported.
      ELSE.
        " [수정 #3] 시작 ------------------------------------------------
        " 기존: 헤더가 있으면 값과 상관없이 무조건 UPDATE
        " 변경: DB 값과 비교해서 다를 때만 UPDATE
        DATA(ls_hdr_db) = lt_hdr_exist[ 1 ].

        IF ls_hdr_db-ItemGroupCode <> ls_p-ItemGroupCode
        OR ls_hdr_db-KiloUnit      <> ls_p-KiloUnit.
          MODIFY ENTITIES OF zmrmd_i_clshdr IN LOCAL MODE
            ENTITY Header
            UPDATE FIELDS ( ItemGroupCode KiloUnit )
            WITH VALUE #( ( CompanyCode          = ls_p-CompanyCode
                            ClassLevel1          = ls_p-ClassLevel1
                            ClassLevel2          = ls_p-ClassLevel2
                            ClassLevel3          = ls_p-ClassLevel3
                            ManufacturingProcess = ls_p-ManufacturingProcess
                            ItemGroupCode        = ls_p-ItemGroupCode
                            KiloUnit             = ls_p-KiloUnit ) )
            FAILED ls_hdr_failed
            REPORTED ls_hdr_reported.
        ENDIF.
        " 값이 같으면 헤더는 손대지 않고 아이템 처리로 진행
        " [수정 #3] 끝 --------------------------------------------------
      ENDIF.

      IF ls_hdr_failed-header IS NOT INITIAL.
        APPEND VALUE #( %cid = ls_key-%cid ) TO failed-header.
        LOOP AT ls_hdr_reported-header INTO DATA(ls_hrep).
          APPEND VALUE #( %cid = ls_key-%cid %msg = ls_hrep-%msg ) TO reported-header.
        ENDLOOP.
        CONTINUE.
      ENDIF.

      "------------------------------------------------------------
      " 2. 아이템 존재 여부 조회 (다른 BO -> IN LOCAL MODE 없이)
      "------------------------------------------------------------
      lt_itm_read = VALUE #( FOR ls_i IN ls_p-_Item
                             ( Plant = ls_i-Plant Material = ls_i-Material ) ).

      " [수정 #4] 신규: 이전 루프 회차 결과가 남지 않도록 초기화
      CLEAR lt_itm_exist.

      IF lt_itm_read IS NOT INITIAL.
        READ ENTITIES OF zmrmd_i_clsitm
          ENTITY Item
          " [수정 #5] 기존: FIELDS ( CompanyCode ItemGroupCode ) → DetailedItemGroupCode 추가
          FIELDS ( CompanyCode ItemGroupCode DetailedItemGroupCode )
          WITH lt_itm_read
          RESULT lt_itm_exist.   " [수정 #1] 기존: RESULT DATA(lt_itm_exist)
      ENDIF.

      "------------------------------------------------------------
      " 3. 생성 / 수정 / 오류 분리
      "------------------------------------------------------------
      LOOP AT ls_p-_Item INTO DATA(ls_item).

        " [수정 #6] 기존: WITH KEY Plant = ... Material = ...
        "           변경: RAP 파생 타입의 보조 키 id(= 엔티티 키) 명시 → 성능 경고 해소
        READ TABLE lt_itm_exist INTO DATA(ls_exist)
             WITH KEY id COMPONENTS Plant    = ls_item-Plant
                                    Material = ls_item-Material.

        IF sy-subrc <> 0.
          " 없음 -> 생성 (CompanyCode, ItemGroupCode는 헤더 값으로)
          APPEND VALUE #( %cid                  = |ITM_{ ls_item-Plant }_{ ls_item-Material }|
                          Plant                 = ls_item-Plant
                          Material              = ls_item-Material
                          CompanyCode           = ls_p-CompanyCode
                          ItemGroupCode         = ls_p-ItemGroupCode
                          DetailedItemGroupCode = ls_item-DetailedItemGroupCode ) TO lt_itm_create.

        ELSEIF ls_exist-CompanyCode   <> ls_p-CompanyCode
            OR ls_exist-ItemGroupCode <> ls_p-ItemGroupCode.
          " 있음 + 다른 품목그룹 소속 -> 오류
          lv_has_error = abap_true.
          APPEND VALUE #( %cid = ls_key-%cid
                          %msg = new_message_with_text(
                                   severity = if_abap_behv_message=>severity-error
                                   text     = |플랜트 { ls_item-Plant } / 자재 { ls_item-Material }는 | &&
                                              |이미 품목그룹 { ls_exist-ItemGroupCode }에 속해 있습니다| ) )
                 TO reported-header.

        " [수정 #7] 기존: ELSE. (같은 품목그룹이면 무조건 UPDATE)
        "           변경: DetailedItemGroupCode가 다를 때만 UPDATE
        ELSEIF ls_exist-DetailedItemGroupCode <> ls_item-DetailedItemGroupCode.
          " 있음 + 같은 품목그룹 + 값 변경 -> 수정
          APPEND VALUE #( Plant                 = ls_item-Plant
                          Material              = ls_item-Material
                          DetailedItemGroupCode = ls_item-DetailedItemGroupCode ) TO lt_itm_update.
        ENDIF.
        " 있음 + 같은 품목그룹 + 값 동일 -> 아무것도 하지 않음
      ENDLOOP.

      IF lv_has_error = abap_true.
        APPEND VALUE #( %cid = ls_key-%cid ) TO failed-header.
        CONTINUE.
      ENDIF.

      "------------------------------------------------------------
      " 4. 아이템 BO에 EML로 생성/수정 (DB 직접 쓰기 X)
      "------------------------------------------------------------
      IF lt_itm_create IS NOT INITIAL OR lt_itm_update IS NOT INITIAL.
        MODIFY ENTITIES OF zmrmd_i_clsitm
          ENTITY Item
            CREATE FIELDS ( Plant Material CompanyCode ItemGroupCode DetailedItemGroupCode )
              WITH lt_itm_create
            UPDATE FIELDS ( DetailedItemGroupCode )
              WITH lt_itm_update
          FAILED   DATA(ls_itm_failed)
          REPORTED DATA(ls_itm_reported).

        IF ls_itm_failed-item IS NOT INITIAL.
          APPEND VALUE #( %cid = ls_key-%cid ) TO failed-header.
          LOOP AT ls_itm_reported-item INTO DATA(ls_irep).
            APPEND VALUE #( %cid = ls_key-%cid %msg = ls_irep-%msg ) TO reported-header.
          ENDLOOP.
        ENDIF.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD setCreateStamp.
    " 서버(시스템) 시간 기준. CDS의 abap_system_timezone 해석과 기준을 맞춤
    DATA(lv_date) = cl_abap_context_info=>get_system_date( ).
    DATA(lv_time) = cl_abap_context_info=>get_system_time( ).

    MODIFY ENTITIES OF zmrmd_i_clshdr IN LOCAL MODE
      ENTITY Header
      UPDATE FIELDS ( CreateDate CreateTime )
      WITH VALUE #( FOR k IN keys ( %tky       = k-%tky
                                    CreateDate = lv_date
                                    CreateTime = lv_time ) ).
  ENDMETHOD.


  METHOD setChangeStamp.
    DATA(lv_date) = cl_abap_context_info=>get_system_date( ).
    DATA(lv_time) = cl_abap_context_info=>get_system_time( ).

    MODIFY ENTITIES OF zmrmd_i_clshdr IN LOCAL MODE
      ENTITY Header
      UPDATE FIELDS ( ChangeDate ChangeTime )
      WITH VALUE #( FOR k IN keys ( %tky       = k-%tky
                                    ChangeDate = lv_date
                                    ChangeTime = lv_time ) ).
  ENDMETHOD.


  METHOD validateCompanyCode.
    READ ENTITIES OF zmrmd_i_clshdr IN LOCAL MODE
      ENTITY Header FIELDS ( CompanyCode ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_data).

    LOOP AT lt_data INTO DATA(ls).
      SELECT SINGLE @abap_true FROM I_CompanyCode
        WHERE CompanyCode = @ls-CompanyCode
        INTO @DATA(lv_exists).
      IF lv_exists = abap_false.
        APPEND VALUE #( %tky = ls-%tky ) TO failed-header.
        APPEND VALUE #( %tky = ls-%tky
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = |회사코드 { ls-CompanyCode }가 존재하지 않습니다| )
                        %element-CompanyCode = if_abap_behv=>mk-on ) TO reported-header.
      ENDIF.
      CLEAR lv_exists.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
