*"* Local Types of ZBP_MRMD_I_CLSHDR

CLASS lhc_header DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR Header RESULT result.


    METHODS setCreateStamp FOR DETERMINE ON SAVE
      IMPORTING keys FOR Header~setCreateStamp.

    " [ETag #3] ON SAVE → ON MODIFY (BDEF와 맞춤). 구현은 그대로
    METHODS setChangeStamp FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Header~setChangeStamp.

    METHODS validateCompanyCode FOR VALIDATE ON SAVE
      IMPORTING keys FOR Header~validateCompanyCode.
ENDCLASS.

CLASS lhc_header IMPLEMENTATION.

  METHOD get_global_authorizations.
    " 권한 체크가 필요하면 AUTHORITY-CHECK 결과를 반영
    result = VALUE #( %create = if_abap_behv=>auth-allowed
                      %update = if_abap_behv=>auth-allowed
                      %delete = if_abap_behv=>auth-allowed ).
  ENDMETHOD.


  METHOD setCreateStamp.
    " 서버(시스템) 시간 기준. CDS의 abap_system_timezone 해석과 기준을 맞춤
    DATA(lv_date) = cl_abap_context_info=>get_system_date( ).
    DATA(lv_time) = cl_abap_context_info=>get_system_time( ).
    " [수정 #9] 2026-11-16 사용자 필드도 직접 세팅 (자동 채움이 안 되는 문제)
    DATA(lv_user) = cl_abap_context_info=>get_user_technical_name( ).

    MODIFY ENTITIES OF zmrmd_i_clshdr IN LOCAL MODE
      ENTITY Header
      UPDATE FIELDS ( CreateDate CreateTime CreatedBy )   " [수정 #9] CreatedBy 추가
      WITH VALUE #( FOR k IN keys ( %tky       = k-%tky
                                    CreateDate = lv_date
                                    CreateTime = lv_time
                                    CreatedBy  = lv_user ) ).   " [수정 #9]
  ENDMETHOD.


  METHOD setChangeStamp.
    DATA(lv_date) = cl_abap_context_info=>get_system_date( ).
    DATA(lv_time) = cl_abap_context_info=>get_system_time( ).
    " [수정 #9] 2026-11-16 사용자 필드도 직접 세팅 (자동 채움이 안 되는 문제)
    DATA(lv_user) = cl_abap_context_info=>get_user_technical_name( ).

    MODIFY ENTITIES OF zmrmd_i_clshdr IN LOCAL MODE
      ENTITY Header
      UPDATE FIELDS ( ChangeDate ChangeTime ChangedBy )   " [수정 #9] ChangedBy 추가
      WITH VALUE #( FOR k IN keys ( %tky       = k-%tky
                                    ChangeDate = lv_date
                                    ChangeTime = lv_time
                                    ChangedBy  = lv_user ) ).   " [수정 #9]
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
