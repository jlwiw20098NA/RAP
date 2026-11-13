# Class Header / Item RAP BO

헤더와 아이템을 **서로 다른 BO**로 두고, 헤더 BO의 static action `SaveAll`이
deep 파라미터(헤더 + 아이템 목록)를 받아 **한 트랜잭션으로 생성/수정**하는 예시입니다.
아이템은 DB에 직접 쓰지 않고 **아이템 BO에 EML**로 요청합니다.

> 이름, 필드 타입·길이, 코드값은 모두 예시입니다. 실제 값으로 바꿔서 사용하세요.

## 폴더 구조

| 폴더 | 내용 |
|---|---|
| `01_tables` | DB 테이블 `zmrmd_t_clshdr`, `zmrmd_t_clsitm` |
| `02_cds` | 하위 뷰(`*Base`)와 BO 루트 뷰 `ZMRMD_I_ClsHdr`, `ZMRMD_I_ClsItm` |
| `03_abstract` | `SaveAll` deep 파라미터용 abstract entity와 abstract BDEF |
| `04_bdef` | 헤더/아이템 BDEF (managed, strict 2) |
| `05_classes` | Behavior pool (글로벌 클래스 + Local Types 구현) |
| `06_service` | Service Definition |

파일 확장자는 오브젝트 종류를 구분하려고 붙인 것입니다. ADT에서 같은 이름의 오브젝트를 만든 뒤 내용을 붙여 넣으세요.
`*.clas.locals_imp.abap`은 클래스의 **Local Types** 탭에 넣습니다.

## 키 구조

| | 키 | 데이터 필드 |
|---|---|---|
| 헤더 | CompanyCode, ClassLevel1, ClassLevel2, ClassLevel3, ManufacturingProcess | ItemGroupCode, KiloUnit |
| 아이템 | Plant, Material | CompanyCode, ItemGroupCode, DetailedItemGroupCode |

- 아이템은 헤더 키를 갖지 않고 **CompanyCode + ItemGroupCode**로만 헤더와 연결됩니다.
- 그래서 아이템 → 헤더 association은 `[0..*]`입니다. 아이템 뷰에서 헤더 필드를 꺼내면 행이 늘어날 수 있어 내비게이션용으로만 둡니다.

## 생성/변경 일시

- 테이블은 `ERDAT/ERZET`, `AEDAT/AEZET` (날짜·시간 분리) 구조입니다.
- 루트 뷰는 원본 필드(`CreateDate`, `CreateTime` ...)를 **매핑용으로 노출(API에서는 숨김)**하고,
  화면 표시용 `CreatedTimestamp`, `ChangedTimestamp`는 `dats_tims_to_tstmp`로 계산합니다.
- 계산 필드는 테이블 컬럼이 없으므로 `mapping for`에 넣지 않고 `readonly`로 둡니다.
- 값은 determination(`setCreateStamp`, `setChangeStamp`)이 **서버 시스템 시간**으로 채웁니다.
  CDS도 `abap_system_timezone`으로 해석하므로 저장 기준과 해석 기준이 같습니다.
- 생성자/변경자(`ERNAM`, `AENAM`)는 실제 컬럼이라 `@Semantics.user.*`로 프레임워크가 채웁니다.

## SaveAll 흐름

```
POST SaveAll (헤더 + 아이템 배열)
  0. payload 안 (Plant, Material) 중복 체크
  1. 헤더(키 5개) 존재 확인 -> CREATE / UPDATE      (헤더 BO, IN LOCAL MODE)
  2. 아이템(Plant, Material) 존재 확인              (아이템 BO, EML)
  3. 없음                      -> CREATE (CompanyCode, ItemGroupCode = 헤더 값)
     있음 + 같은 품목그룹       -> UPDATE (DetailedItemGroupCode)
     있음 + 다른 품목그룹       -> 오류
  4. 아이템 BO에 MODIFY ENTITIES
  -> 하나라도 failed면 전체 롤백
  -> 저장 단계: determination(일시), validation(회사코드, 플랜트/자재)
  -> 두 테이블 저장, COMMIT 한 번
```

## 호출 예시 (OData V4 Web API)

```
POST {base}Header/SAP__self.SaveAll
Content-Type: application/json
X-CSRF-Token: <GET {base} 에 X-CSRF-Token: Fetch 로 받은 토큰>
```

```json
{
  "CompanyCode": "1000",
  "ClassLevel1": "SB",
  "ClassLevel2": "L2A",
  "ClassLevel3": "L3A",
  "ManufacturingProcess": "PKG",
  "ItemGroupCode": "IG01",
  "KiloUnit": "KG",
  "_Item": [
    { "Plant": "1100", "Material": "MAT001", "DetailedItemGroupCode": "DIG01" },
    { "Plant": "1100", "Material": "MAT002", "DetailedItemGroupCode": "DIG02" }
  ]
}
```

action 이름 접두사와 deep 파라미터 JSON 형태는 `{base}$metadata`에서 확인하세요.

## 활성화 순서

1. 테이블 2개
2. `*Base` 뷰 2개
3. 루트 뷰 2개 (서로 association으로 참조하므로 **함께 선택해 한 번에 활성화**)
4. abstract entity 2개 + abstract BDEF
5. BDEF 2개 → Quick Fix(Ctrl+1)로 behavior pool 생성 후 Local Types 내용 교체
6. Service Definition → Service Binding(OData V4 - Web API) 생성 후 Publish

## 확인할 점

- **릴리스**: deep 파라미터와 abstract BDEF(`with hierarchy`)는 비교적 최신 릴리스 기능입니다.
- **ETag 없음**: 계산 타임스탬프는 버퍼에서 값이 갱신되지 않을 수 있어 `etag master`로 쓰지 않았습니다.
  동시 수정 체크가 필요하면 실제 컬럼 기반 필드를 따로 두세요.
- **변경 일시 트리거**: `setChangeStamp`는 업무 필드(헤더: ItemGroupCode, KiloUnit / 아이템: DetailedItemGroupCode)를
  트리거로 걸었습니다. 생성 시에도 이 필드가 채워지면 변경 일시가 함께 들어갑니다.
  생성 때 변경 일시를 비워야 한다면 로직 조정이 필요합니다. 업무 필드가 늘면 트리거 목록에도 추가하세요.
- **시간 기준**: `cl_abap_context_info=>get_system_date/time`은 시스템 시간대 기준입니다.
  기존 데이터의 ERDAT/ERZET 기준과 같은지 확인하세요.

## 열린 결정 사항

1. 헤더의 `ItemGroupCode`를 바꾸면 기존 아이템과 연결이 끊깁니다. 수정을 막을지(`readonly : update`), 아이템도 같이 바꿀지 정해야 합니다.
2. 여러 헤더가 같은 `CompanyCode + ItemGroupCode`를 가질 수 있는지. 안 된다면 헤더 중복 방지 validation을 추가하세요.
3. 다른 품목그룹에 속한 아이템이 들어오면 지금은 오류입니다. 이동을 허용할지.
4. payload에 없는 기존 아이템은 지금은 유지됩니다. 삭제가 필요한지.
5. 헤더 삭제 시 아이템도 함께 삭제할지 (별도 BO라 자동 삭제되지 않음).
