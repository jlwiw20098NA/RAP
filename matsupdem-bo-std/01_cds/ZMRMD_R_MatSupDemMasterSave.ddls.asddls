@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Material Supplier Demand Master - Save BO Root'
// 저장용 BO 루트 (ZTMRMD00410)
// - 조회는 별도 조회 뷰 ZMRMD_R_MatSupDemMaster 사용
// - 저장은 표준 POST / PATCH / DELETE ($batch changeset으로 묶어서 한 LUW)
// TODO: ZMRMD_I_ZTMRMD00410의 실제 필드명으로 맞추세요 (SupplyRatio, Remark는 예시 필드)
define root view entity ZMRMD_R_MatSupDemMasterSave
  as select from ZMRMD_I_ZTMRMD00410
{
  key CompanyCode,
  key Material,
  key Supplier,
  key GoodsSupplier,
      SupplyRatio,     // 예시 필드 1 (U 대상)
      Remark           // 예시 필드 2 (U 대상)
}
