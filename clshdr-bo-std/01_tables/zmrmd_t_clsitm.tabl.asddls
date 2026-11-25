@EndUserText.label : 'Class Item'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zmrmd_t_clsitm {
  key client        : abap.clnt not null;
  key plant         : werks_d not null;
  key material      : matnr not null;
  company_code      : bukrs;               // 헤더 연결 (키 아님)
  item_group        : abap.char(10);       // 헤더 연결 (키 아님)
  detail_item_group : abap.char(10);
  erdat             : abap.dats;           // 생성일
  erzet             : abap.tims;           // 생성시간
  ernam             : abp_creation_user;   // 생성자
  aedat             : abap.dats;           // 변경일
  aezet             : abap.tims;           // 변경시간
  aenam             : abp_lastchange_user; // 변경자
}
