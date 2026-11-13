@EndUserText.label: 'SaveAll Param - Header'
// SaveAll action의 deep 파라미터 루트
define root abstract entity ZMRMD_A_SaveClsHdr
{
  CompanyCode          : bukrs;
  ClassLevel1          : abap.char(10);
  ClassLevel2          : abap.char(10);
  ClassLevel3          : abap.char(10);
  ManufacturingProcess : abap.char(10);
  ItemGroupCode        : abap.char(10);
  KiloUnit             : abap.char(10);
  _Item                : composition [0..*] of ZMRMD_A_SaveClsItm;
}
