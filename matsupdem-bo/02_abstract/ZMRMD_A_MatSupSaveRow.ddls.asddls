@EndUserText.label: 'SaveAll Param - Row'
// TODO: 타입/길이를 ZTMRMD00410 필드와 맞추세요
define abstract entity ZMRMD_A_MatSupSaveRow
{
  Status        : abap.char(1);       // C / U / D (DB 저장 안 함)
  CompanyCode   : bukrs;
  Material      : matnr;
  Supplier      : lifnr;
  GoodsSupplier : lifnr;
  SupplyRatio   : abap.dec(5,2);      // 예시 필드 1
  Remark        : abap.char(100);     // 예시 필드 2
  _Req          : association to parent ZMRMD_A_MatSupSaveReq;
}
