@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Detailed Item Group Mng - BO Root'
// BO 루트 (MngSave)
// - 파라미터(P_Gubun)와 Status 키는 BO 루트에 둘 수 없어서 원천 뷰 기준으로 구성
// - [표준 #1] Status(C/U/D) 대신 HTTP 메서드로 구분: POST = C, PATCH = U, DELETE = D
// TODO: ZMRMD_I_ZTMRMD00440의 실제 필드명으로 맞추세요
define root view entity ZMRMD_R_DtlItemMng
  as select from ZMRMD_I_ZTMRMD00440
  composition [0..*] of ZMRMD_R_DtlItemUser as _User
{
  key CompanyCode,
  key ItemGroupCode,
  key DetailedItemGroupCode,
      DetailedItemGroupName,
      Remark,

      // 원본 날짜/시간: 매핑 대상, API에는 숨김. determination이 채움
      @Consumption.hidden: true
      CreatedDate,
      @Consumption.hidden: true
      CreatedTime,
      @Consumption.hidden: true
      ChangedDate,
      @Consumption.hidden: true
      ChangedTime,

      // 화면 표시용 타임스탬프 (계산 필드, 매핑 없음, 읽기 전용)
      dats_tims_to_tstmp( CreatedDate, CreatedTime,
                          abap_system_timezone( $session.client, 'NULL' ),
                          $session.client, 'NULL' ) as CreatedTimeStamp,
      dats_tims_to_tstmp( ChangedDate, ChangedTime,
                          abap_system_timezone( $session.client, 'NULL' ),
                          $session.client, 'NULL' ) as ChangedTimeStamp,

      CreatedBy,
      ChangedBy,

      _User
}
