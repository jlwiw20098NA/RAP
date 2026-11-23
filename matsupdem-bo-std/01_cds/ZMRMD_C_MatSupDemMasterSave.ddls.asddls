@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Material Supplier Demand Master - Save Projection'
define root view entity ZMRMD_C_MatSupDemMasterSave
  provider contract transactional_query
  as projection on ZMRMD_R_MatSupDemMasterSave
{
  key CompanyCode,
  key Material,
  key Supplier,
  key GoodsSupplier,
      SupplyRatio,
      Remark,
      // [수정 #1] 화면 표시용 생성/변경 정보
      CreatedTimeStamp,
      CreatedBy,
      ChangedTimeStamp,
      ChangedBy
}
