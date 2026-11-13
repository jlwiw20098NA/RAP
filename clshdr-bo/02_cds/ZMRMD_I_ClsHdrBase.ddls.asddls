@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Class Header - Base'
// 테이블 1행 = 뷰 1행. 조인/집계 없이 이름만 정리하는 하위 뷰
define view entity ZMRMD_I_ClsHdrBase
  as select from zmrmd_t_clshdr
{
  key company_code as CompanyCode,
  key class_level1 as ClassLevel1,
  key class_level2 as ClassLevel2,
  key class_level3 as ClassLevel3,
  key mfg_process  as ManufacturingProcess,
      item_group   as ItemGroupCode,
      kilo_unit    as KiloUnit,
      erdat        as CreateDate,
      erzet        as CreateTime,
      ernam        as CreatedBy,
      aedat        as ChangeDate,
      aezet        as ChangeTime,
      aenam        as ChangedBy
}
