@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Class Item - Base'
// 테이블 1행 = 뷰 1행. 조인/집계 없이 이름만 정리하는 하위 뷰
define view entity ZMRMD_I_ClsItmBase
  as select from zmrmd_t_clsitm
{
  key plant             as Plant,
  key material          as Material,
      company_code      as CompanyCode,
      item_group        as ItemGroupCode,
      detail_item_group as DetailedItemGroupCode,
      erdat             as CreateDate,
      erzet             as CreateTime,
      ernam             as CreatedBy,
      aedat             as ChangeDate,
      aezet             as ChangeTime,
      aenam             as ChangedBy
}
