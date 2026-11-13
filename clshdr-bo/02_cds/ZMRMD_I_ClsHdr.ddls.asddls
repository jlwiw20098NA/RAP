@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Class Header'
// BO 루트 뷰 (헤더). 서비스에 바로 노출 (Projection 없음)
define root view entity ZMRMD_I_ClsHdr
  as select from ZMRMD_I_ClsHdrBase
  association [0..*] to ZMRMD_I_ClsItm as _Item
    on  $projection.CompanyCode   = _Item.CompanyCode
    and $projection.ItemGroupCode = _Item.ItemGroupCode
{
  key CompanyCode,
  key ClassLevel1,
  key ClassLevel2,
  key ClassLevel3,
  key ManufacturingProcess,
      ItemGroupCode,
      KiloUnit,

      // 원본 날짜/시간: 매핑 대상, API에는 숨김. determination이 채움
      @Consumption.hidden: true
      CreateDate,
      @Consumption.hidden: true
      CreateTime,
      @Consumption.hidden: true
      ChangeDate,
      @Consumption.hidden: true
      ChangeTime,

      // 화면 표시용 타임스탬프: 계산 필드, 매핑 없음, 읽기 전용
      // 저장 시 시스템 시간대 기준으로 넣으므로 해석도 시스템 시간대로
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

      _Item
}
