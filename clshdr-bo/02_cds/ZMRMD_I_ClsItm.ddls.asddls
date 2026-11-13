@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Class Item'
// BO 루트 뷰 (아이템). 헤더와 별도의 BO. 서비스에 바로 노출 (Projection 없음)
define root view entity ZMRMD_I_ClsItm
  as select from ZMRMD_I_ClsItmBase
  // 헤더 키 전체가 아니라 CompanyCode + ItemGroupCode로만 연결되므로 to-many
  // 이 association에서 필드를 꺼내면 행이 늘어날 수 있으니 내비게이션용으로만 사용
  association [0..*] to ZMRMD_I_ClsHdr as _Header
    on  $projection.CompanyCode   = _Header.CompanyCode
    and $projection.ItemGroupCode = _Header.ItemGroupCode
{
  key Plant,
  key Material,
      CompanyCode,
      ItemGroupCode,
      DetailedItemGroupCode,

      @Consumption.hidden: true
      CreateDate,
      @Consumption.hidden: true
      CreateTime,
      @Consumption.hidden: true
      ChangeDate,
      @Consumption.hidden: true
      ChangeTime,

      dats_tims_to_tstmp( CreateDate, CreateTime,
                          abap_system_timezone( $session.client, 'NULL' ),
                          $session.client, 'NULL' ) as CreatedTimestamp,
      dats_tims_to_tstmp( ChangeDate, ChangeTime,
                          abap_system_timezone( $session.client, 'NULL' ),
                          $session.client, 'NULL' ) as ChangedTimestamp,

      @Semantics.user.createdBy: true
      CreatedBy,
      @Semantics.user.lastChangedBy: true
      ChangedBy,

      _Header
}
