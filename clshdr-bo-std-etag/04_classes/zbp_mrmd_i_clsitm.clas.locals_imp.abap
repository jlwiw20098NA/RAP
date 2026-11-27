*"* Local Types of ZBP_MRMD_I_CLSITM

CLASS lhc_item DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR Item RESULT result.

    METHODS setCreateStamp FOR DETERMINE ON SAVE
      IMPORTING keys FOR Item~setCreateStamp.

    METHODS setChangeStamp FOR DETERMINE ON SAVE
      IMPORTING keys FOR Item~setChangeStamp.

    METHODS validatePlantMaterial FOR VALIDATE ON SAVE
      IMPORTING keys FOR Item~validatePlantMaterial.

    " [ETag #5] ETag 값(LastChangedAt) 채우기
    METHODS setEtag FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Item~setEtag.
ENDCLASS.

CLASS lhc_item IMPLEMENTATION.

  METHOD get_global_authorizations.
    result = VALUE #( %create = if_abap_behv=>auth-allowed
                      %update = if_abap_behv=>auth-allowed
                      %delete = if_abap_behv=>auth-allowed ).
  ENDMETHOD.


  METHOD setCreateStamp.
    DATA(lv_date) = cl_abap_context_info=>get_system_date( ).
    DATA(lv_time) = cl_abap_context_info=>get_system_time( ).
    " [수정 #9] 2026-11-16 사용자 필드도 직접 세팅 (자동 채움이 안 되는 문제)
    DATA(lv_user) = cl_abap_context_info=>get_user_technical_name( ).

    MODIFY ENTITIES OF zmrmd_i_clsitm IN LOCAL MODE
      ENTITY Item
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

    MODIFY ENTITIES OF zmrmd_i_clsitm IN LOCAL MODE
      ENTITY Item
      UPDATE FIELDS ( ChangeDate ChangeTime ChangedBy )   " [수정 #9] ChangedBy 추가
      WITH VALUE #( FOR k IN keys ( %tky       = k-%tky
                                    ChangeDate = lv_date
                                    ChangeTime = lv_time
                                    ChangedBy  = lv_user ) ).   " [수정 #9]
  ENDMETHOD.


  METHOD validatePlantMaterial.
    READ ENTITIES OF zmrmd_i_clsitm IN LOCAL MODE
      ENTITY Item FIELDS ( Plant Material ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_items).

    LOOP AT lt_items INTO DATA(ls).
      " [수정 #8] 2026-11-16 DCL 우회
      " 기존: SELECT ... FROM I_ProductPlantBasic (authorizationCheck #CHECK → 권한 없는 행이 걸러져
      "       자재가 있어도 '없음'으로 판단되어 저장 실패)
      " 변경: WITH PRIVILEGED ACCESS → 이 SELECT에서만 CDS 접근 제어(DCL)를 적용하지 않음
      "       존재 여부만 보는 기술적 검증이라 우회. 사용자 권한 체크는 authorization 메서드에서 처리
      SELECT SINGLE @abap_true FROM I_ProductPlantBasic
        WHERE Product = @ls-Material
          AND Plant   = @ls-Plant
        INTO @DATA(lv_exists)
        WITH PRIVILEGED ACCESS.
      IF lv_exists = abap_false.
        APPEND VALUE #( %tky = ls-%tky ) TO failed-item.
        APPEND VALUE #( %tky = ls-%tky
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = |플랜트 { ls-Plant }에 자재 { ls-Material }가 없습니다| )
                        %element-Material = if_abap_behv=>mk-on ) TO reported-item.
      ENDIF.
      CLEAR lv_exists.
    ENDLOOP.
  ENDMETHOD.

  METHOD setEtag.
    " [ETag #5] 2026-11-27 생성·수정 때마다 현재 UTC 타임스탬프(소수점 7자리)로 갱신
    "  초 단위(get_system_time)는 같은 초에 두 번 수정하면 ETag가 같아져서 쓰지 않음
    DATA lv_ts TYPE timestampl.        " 테이블 필드 타입 abp_lastchange_tstmpl과 같은 타입
    GET TIME STAMP FIELD lv_ts.

    MODIFY ENTITIES OF zmrmd_i_clsitm IN LOCAL MODE
      ENTITY Item
      UPDATE FIELDS ( LastChangedAt )
      WITH VALUE #( FOR k IN keys ( %tky          = k-%tky
                                    LastChangedAt = lv_ts ) ).
  ENDMETHOD.

ENDCLASS.
