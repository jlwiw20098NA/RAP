@EndUserText.label: 'SaveAll Param - Request Root'
// SaveAll deep 파라미터 루트
// Mng 목록과 User 목록을 형제로 받음 -> Mng만 / User만 / 둘 다 보낼 수 있음
define root abstract entity ZMRMD_A_DtlSaveReq
{
  Dummy : abap.char(1);   // 루트에 필드가 하나는 있어야 해서 둔 자리. 비워서 보내면 됨
  _Mng  : composition [0..*] of ZMRMD_A_DtlSaveMng;
  _User : composition [0..*] of ZMRMD_A_DtlSaveUser;
}
