@EndUserText.label: 'SaveAll Param - Request Root'
define root abstract entity ZMRMD_A_MatSupSaveReq
{
  Dummy : abap.char(1);   // 루트에 필드가 하나는 있어야 해서 둔 자리. 비워서 보내면 됨
  _Row  : composition [0..*] of ZMRMD_A_MatSupSaveRow;
}
