@EndUserText.label: 'SaveAll Param - User Row'
// TODO: 타입/길이를 테이블(ZTMRMD00441) 필드와 맞추세요
define abstract entity ZMRMD_A_DtlSaveUser
{
  Status                : abap.char(1);    // C / D (사번은 키라 U 없음)
  CompanyCode           : bukrs;
  ItemGroupCode         : abap.char(10);
  DetailedItemGroupCode : abap.char(10);
  UserID                : abap.char(12);
  _Req                  : association to parent ZMRMD_A_DtlSaveReq;
}
