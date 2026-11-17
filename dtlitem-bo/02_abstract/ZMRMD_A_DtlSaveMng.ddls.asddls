@EndUserText.label: 'SaveAll Param - Mng Row'
// TODO: 타입/길이를 테이블(ZTMRMD00440) 필드와 맞추세요
define abstract entity ZMRMD_A_DtlSaveMng
{
  Status                : abap.char(1);    // C / U / D (DB 저장 안 함)
  CompanyCode           : bukrs;
  ItemGroupCode         : abap.char(10);
  DetailedItemGroupCode : abap.char(10);
  DetailedItemGroupName : abap.char(40);
  Remark                : abap.char(255);
  _Req                  : association to parent ZMRMD_A_DtlSaveReq;
}
