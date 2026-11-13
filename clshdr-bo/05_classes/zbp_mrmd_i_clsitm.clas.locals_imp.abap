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

    MODIFY ENTITIES OF zmrmd_i_clsitm IN LOCAL MODE
      ENTITY Item
      UPDATE FIELDS ( CreateDate CreateTime )
      WITH VALUE #( FOR k IN keys ( %tky       = k-%tky
                                    CreateDate = lv_date
                                    CreateTime = lv_time ) ).
  ENDMETHOD.


  METHOD setChangeStamp.
    DATA(lv_date) = cl_abap_context_info=>get_system_date( ).
    DATA(lv_time) = cl_abap_context_info=>get_system_time( ).

    MODIFY ENTITIES OF zmrmd_i_clsitm IN LOCAL MODE
      ENTITY Item
      UPDATE FIELDS ( ChangeDate ChangeTime )
      WITH VALUE #( FOR k IN keys ( %tky       = k-%tky
                                    ChangeDate = lv_date
                                    ChangeTime = lv_time ) ).
  ENDMETHOD.


  METHOD validatePlantMaterial.
    READ ENTITIES OF zmrmd_i_clsitm IN LOCAL MODE
      ENTITY Item FIELDS ( Plant Material ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_items).

    LOOP AT lt_items INTO DATA(ls).
      SELECT SINGLE @abap_true FROM I_ProductPlantBasic
        WHERE Product = @ls-Material
          AND Plant   = @ls-Plant
        INTO @DATA(lv_exists).
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

ENDCLASS.
