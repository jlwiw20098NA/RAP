@EndUserText.label: 'SaveAll Param - Item'
// 아이템의 CompanyCode, ItemGroupCode는 받지 않음 -> 서버가 헤더 값으로 채움
define abstract entity ZMRMD_A_SaveClsItm
{
  Plant                 : werks_d;
  Material              : matnr;
  DetailedItemGroupCode : abap.char(10);
  _Header               : association to parent ZMRMD_A_SaveClsHdr;
}
