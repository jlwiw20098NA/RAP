@EndUserText.label : 'Class Header'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zmrmd_t_clshdr {
  key client       : abap.clnt not null;
  key company_code : bukrs not null;
  key class_level1 : abap.char(10) not null;
  key class_level2 : abap.char(10) not null;
  key class_level3 : abap.char(10) not null;
  key mfg_process  : abap.char(10) not null;
  item_group       : abap.char(10);
  kilo_unit        : abap.char(10);
  erdat            : abap.dats;           // 생성일
  erzet            : abap.tims;           // 생성시간
  ernam            : abp_creation_user;   // 생성자
  aedat            : abap.dats;           // 변경일
  aezet            : abap.tims;           // 변경시간
  aenam            : abp_lastchange_user; // 변경자
}
