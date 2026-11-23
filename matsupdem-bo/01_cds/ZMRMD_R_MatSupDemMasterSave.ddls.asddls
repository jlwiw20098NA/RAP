@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Material Supplier Demand Master - Save BO Root'
// 저장용 BO 루트 (ZTMRMD00410)
// - 조회는 별도 조회 뷰 ZMRMD_R_MatSupDemMaster 사용
// - 저장은 SaveAll action으로만 (Status C/U/D)
// TODO: ZMRMD_I_ZTMRMD00410의 실제 필드명으로 맞추세요 (SupplyRatio, Remark는 예시 필드)
define root view entity ZMRMD_R_MatSupDemMasterSave
  as select from ZMRMD_I_ZTMRMD00410
{
  key CompanyCode,
  key Material,
  key Supplier,
  key GoodsSupplier,
      SupplyRatio,     // 예시 필드 1 (U 대상)
      Remark,          // 예시 필드 2 (U 대상)
      // [수정 #3] 삭제지시자: D는 물리 삭제 대신 이 값을 'X'(true)로 바꿈
      // TODO: ZMRMD_I_ZTMRMD00410의 실제 필드명으로 맞추세요
      DeletionIndicator,

      // [수정 #1] 생성/변경 일시·사용자 추가 (매핑 대상, determination이 채움)
      // TODO: ZMRMD_I_ZTMRMD00410의 실제 필드명으로 맞추세요
      @Consumption.hidden: true
      CreatedDate,
      @Consumption.hidden: true
      CreatedTime,
      CreatedBy,
      @Consumption.hidden: true
      ChangedDate,
      @Consumption.hidden: true
      ChangedTime,
      ChangedBy,

      // [수정 #1] 화면 표시용 타임스탬프 (계산 필드, 매핑 없음)
      dats_tims_to_tstmp( CreatedDate, CreatedTime,
                          abap_system_timezone( $session.client, 'NULL' ),
                          $session.client, 'NULL' ) as CreatedTimeStamp,
      dats_tims_to_tstmp( ChangedDate, ChangedTime,
                          abap_system_timezone( $session.client, 'NULL' ),
                          $session.client, 'NULL' ) as ChangedTimeStamp
}
