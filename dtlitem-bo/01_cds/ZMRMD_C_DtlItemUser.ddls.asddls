@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Detailed Item Group User - Projection'
define view entity ZMRMD_C_DtlItemUser
  as projection on ZMRMD_R_DtlItemUser
{
  key CompanyCode,
  key ItemGroupCode,
  key DetailedItemGroupCode,
  key UserID,
      CreatedTimeStamp,
      ChangedTimeStamp,
      CreatedBy,
      ChangedBy,
      _Mng : redirected to parent ZMRMD_C_DtlItemMng
}
