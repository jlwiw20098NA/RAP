"! 디버깅 연습용 콘솔 클래스
"! ADT에서 F9(Run as ABAP Application - Console)로 실행
"! 원하는 줄 왼쪽 눈금을 더블클릭해 브레이크포인트를 걸고 실행하면 디버거가 멈춤
CLASS zcl_debug_test DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.

    TYPES: BEGIN OF ty_item,
             id     TYPE i,
             name   TYPE string,
             price  TYPE p LENGTH 10 DECIMALS 2,
             qty    TYPE i,
             amount TYPE p LENGTH 12 DECIMALS 2,
           END OF ty_item,
           tt_item TYPE STANDARD TABLE OF ty_item WITH EMPTY KEY.

  PRIVATE SECTION.
    METHODS build_data
      RETURNING VALUE(rt_items) TYPE tt_item.

    METHODS calc_amount
      CHANGING ct_items TYPE tt_item.

    METHODS get_total
      IMPORTING it_items        TYPE tt_item
      RETURNING VALUE(rv_total) TYPE ty_item-amount.
ENDCLASS.


CLASS zcl_debug_test IMPLEMENTATION.

  METHOD if_oo_adt_classrun~main.
    " 1. 테스트 데이터 만들기
    DATA(lt_items) = build_data( ).
    out->write( |1) 데이터 { lines( lt_items ) }건 생성| ).

    " 2. 금액 계산 (여기 브레이크포인트 걸고 F5로 메서드 안으로 들어가 보기)
    calc_amount( CHANGING ct_items = lt_items ).
    out->write( '2) 금액 계산 결과' ).
    out->write( lt_items ).

    " 3. 조건 필터링
    DATA(lt_expensive) = VALUE tt_item(
      FOR ls IN lt_items WHERE ( amount >= 10000 ) ( ls ) ).
    out->write( |3) 1만원 이상: { lines( lt_expensive ) }건| ).

    " 4. 합계
    DATA(lv_total) = get_total( lt_items ).
    out->write( |4) 총합계: { lv_total }| ).

    " 5. 분기 확인
    IF lv_total > 50000.
      out->write( '5) 5만원 초과' ).
    ELSE.
      out->write( '5) 5만원 이하' ).
    ENDIF.

    " 6. (선택) 실제 테이블 조회 - 시스템에 있는 테이블로 바꿔서 사용
    " SELECT * FROM /dmo/travel INTO TABLE @DATA(lt_travel) UP TO 10 ROWS.
    " out->write( lt_travel ).

    " 7. (선택) RAP BO를 EML로 읽기 - 본인 BO 이름으로 바꿔서 사용
    " READ ENTITIES OF zi_travel
    "   ENTITY Travel ALL FIELDS WITH VALUE #( ( TravelId = '00000001' ) )
    "   RESULT DATA(lt_result)
    "   FAILED DATA(ls_failed).
    " out->write( lt_result ).
  ENDMETHOD.


  METHOD build_data.
    rt_items = VALUE #(
      ( id = 1 name = '사과'   price = '1500.00'  qty = 3 )
      ( id = 2 name = '바나나' price = '3000.00'  qty = 5 )
      ( id = 3 name = '수박'   price = '18000.00' qty = 1 )
      ( id = 4 name = '포도'   price = '7000.00'  qty = 2 ) ).
  ENDMETHOD.


  METHOD calc_amount.
    LOOP AT ct_items ASSIGNING FIELD-SYMBOL(<ls_item>).
      " 루프 안에서 <ls_item> 값이 바뀌는 걸 변수 창에서 확인
      <ls_item>-amount = <ls_item>-price * <ls_item>-qty.
    ENDLOOP.
  ENDMETHOD.


  METHOD get_total.
    LOOP AT it_items INTO DATA(ls_item).
      rv_total = rv_total + ls_item-amount.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
