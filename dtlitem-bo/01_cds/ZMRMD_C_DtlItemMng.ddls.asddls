@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Detailed Item Group Mng - Projection'
define root view entity ZMRMD_C_DtlItemMng
  provider contract transactional_query
  as projection on ZMRMD_R_DtlItemMng
{
  key CompanyCode,
  key ItemGroupCode,
  key DetailedItemGroupCode,
      DetailedItemGroupName,
      Remark,
      CreatedTimeStamp,
      ChangedTimeStamp,
      CreatedBy,
      ChangedBy,
      _User : redirected to composition child ZMRMD_C_DtlItemUser
}
