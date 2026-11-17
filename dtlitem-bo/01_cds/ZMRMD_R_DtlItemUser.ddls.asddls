@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Detailed Item Group User - BO Child'
// BO 자식 (UserSave). MngSave 키 + 담당자 사번
// TODO: ZMRMD_I_ZTMRMD00441의 실제 필드명으로 맞추세요
define view entity ZMRMD_R_DtlItemUser
  as select from ZMRMD_I_ZTMRMD00441
  association to parent ZMRMD_R_DtlItemMng as _Mng
    on  $projection.CompanyCode           = _Mng.CompanyCode
    and $projection.ItemGroupCode         = _Mng.ItemGroupCode
    and $projection.DetailedItemGroupCode = _Mng.DetailedItemGroupCode
{
  key CompanyCode,
  key ItemGroupCode,
  key DetailedItemGroupCode,
  key UserID,

      @Consumption.hidden: true
      CreatedDate,
      @Consumption.hidden: true
      CreatedTime,
      @Consumption.hidden: true
      ChangedDate,
      @Consumption.hidden: true
      ChangedTime,

      dats_tims_to_tstmp( CreatedDate, CreatedTime,
                          abap_system_timezone( $session.client, 'NULL' ),
                          $session.client, 'NULL' ) as CreatedTimeStamp,
      dats_tims_to_tstmp( ChangedDate, ChangedTime,
                          abap_system_timezone( $session.client, 'NULL' ),
                          $session.client, 'NULL' ) as ChangedTimeStamp,

      CreatedBy,
      ChangedBy,

      _Mng
}
