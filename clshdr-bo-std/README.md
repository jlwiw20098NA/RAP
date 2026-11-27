# Class Header / Item RAP BO — 표준 HTTP 버전

`clshdr-bo/`(SaveAll + abstract entity 버전)과 같은 BO를, **표준 POST / PATCH / DELETE**로 저장하도록 바꾼 버전입니다.
SaveAll action과 abstract entity(`ZMRMD_A_SaveClsHdr`, `ZMRMD_A_SaveClsItm`)가 없습니다.

> 오브젝트 이름이 `clshdr-bo`와 같습니다. 시스템에는 **둘 중 하나만** 올리세요.
> SaveAll 버전을 이미 올렸다면 헤더 BDEF에서 action을 지우고, behavior pool에서 `SaveAll` 메서드를 지운 뒤 abstract entity를 삭제하면 됩니다.

## 폴더 구조

| 폴더 | 내용 |
|---|---|
| `01_tables` | `zmrmd_t_clshdr`, `zmrmd_t_clsitm` (변경 없음) |
| `02_cds` | Base 뷰, 루트 뷰 (변경 없음) |
| `03_bdef` | 헤더·아이템 BDEF — 헤더에서 `static action SaveAll` 제거 |
| `04_classes` | 헤더 behavior pool에서 `SaveAll` 제거. 나머지(determination, validation) 동일 |
| `05_service` | Service Definition (변경 없음) |

## SaveAll 버전과 달라진 점

| | SaveAll 버전 | 표준 HTTP 버전 |
|---|---|---|
| 헤더 생성/수정 | SaveAll이 DB를 보고 판단 (없으면 생성, 다르면 수정, 같으면 건너뜀) | **화면이 정함**: 없으면 `POST`, 있으면 `PATCH` |
| 아이템 생성/수정 | SaveAll이 판단 | 화면이 `POST` / `PATCH` |
| 아이템의 CompanyCode·ItemGroupCode | SaveAll이 헤더 값으로 채움 | **화면이 POST 본문에 직접 넣음** |
| 아이템이 다른 품목그룹에 이미 있음 | SaveAll이 한국어 메시지로 막음 | 같은 키(Plant, Material)로 `POST` → 프레임워크가 중복으로 거절 |
| 헤더·아이템을 한 번에 | JSON 한 번 | **`$batch` changeset 하나**로 묶음 |
| 값이 같으면 건너뛰기 | SaveAll에서 처리 | 없음. 바뀐 행만 보내도록 화면에서 처리 |

그대로인 것: 생성·변경 일시·사용자 determination, 회사코드 validation(헤더), 플랜트·자재 validation(아이템, `WITH PRIVILEGED ACCESS`).

## 요청 형태

| 작업 | 요청 |
|---|---|
| 헤더 생성 | `POST Header` |
| 헤더 수정 | `PATCH Header(CompanyCode='..',ClassLevel1='..',ClassLevel2='..',ClassLevel3='..',ManufacturingProcess='..')` (ItemGroupCode, KiloUnit만 수정 가능) |
| 헤더 삭제 | `DELETE Header(...)` (아이템은 별도 BO라 자동 삭제 안 됨) |
| 아이템 생성 | `POST Item` |
| 아이템 수정 | `PATCH Item(Plant='..',Material='..')` (ItemGroupCode, DetailedItemGroupCode만 수정 가능) |
| 아이템 삭제 | `DELETE Item(Plant='..',Material='..')` |

## `$batch` 예시 (헤더 생성 + 아이템 2건 생성, 한 LUW)

```
POST {base}$batch
Content-Type: multipart/mixed; boundary=batch_1
X-CSRF-Token: <토큰>
```

```
--batch_1
Content-Type: multipart/mixed; boundary=changeset_1

--changeset_1
Content-Type: application/http
Content-Transfer-Encoding: binary
Content-ID: 1

POST Header HTTP/1.1
Content-Type: application/json

{"CompanyCode":"1000","ClassLevel1":"SS50","ClassLevel2":"SS5020","ClassLevel3":"SMOC0203","ManufacturingProcess":"SUB","ItemGroupCode":"BG003","KiloUnit":"1K"}
--changeset_1
Content-Type: application/http
Content-Transfer-Encoding: binary
Content-ID: 2

POST Item HTTP/1.1
Content-Type: application/json

{"Plant":"1100","Material":"MAT001","CompanyCode":"1000","ItemGroupCode":"BG003","DetailedItemGroupCode":"DIG01"}
--changeset_1
Content-Type: application/http
Content-Transfer-Encoding: binary
Content-ID: 3

POST Item HTTP/1.1
Content-Type: application/json

{"Plant":"1100","Material":"MAT002","CompanyCode":"1000","ItemGroupCode":"BG003","DetailedItemGroupCode":"DIG02"}
--changeset_1--
--batch_1--
```

- changeset 안의 요청은 **한 트랜잭션**입니다. 헤더와 아이템이 다른 BO여도 같은 changeset이면 함께 저장되거나 함께 롤백됩니다.
- 줄바꿈은 **CRLF**, 헤더와 본문 사이에는 **빈 줄**이 필요합니다.
- 수정은 `PATCH`, 삭제는 `DELETE` 요청을 같은 changeset에 넣으면 됩니다. ETag가 없어서 `If-Match: *`를 붙이세요.
- 요청을 changeset 없이 따로 보내면 **요청마다 따로 커밋**됩니다. 한쪽만 저장되는 일이 생길 수 있으니 꼭 changeset으로 묶으세요.

## 수정(PATCH) [수정 #10]

| | 수정 가능 필드 | 수정 불가 |
|---|---|---|
| 헤더 | `ItemGroupCode`, `KiloUnit` | 키 5개, 생성·변경 일시/사용자 |
| 아이템 | `ItemGroupCode`, `DetailedItemGroupCode` | `Plant`, `Material`, `CompanyCode`, 생성·변경 일시/사용자 |

- 본문에 **들어온 필드만** 그 값으로 바뀌고, 빠진 필드는 기존 값을 유지합니다 (PATCH 기본 동작).
- 수정 불가 필드를 본문에 넣으면 readonly 오류(400)가 납니다. 키는 URL에만 씁니다.
- 수정 가능 필드가 바뀌면 `setChangeStamp`가 변경일시·변경자를 채웁니다.
- 헤더·아이템 모두 `If-Match: *`가 필요합니다 (ETag 없음).

### 단건

```
PATCH {base}Header(CompanyCode='1000',ClassLevel1='SS50',ClassLevel2='SS5020',ClassLevel3='SMOC0203',ManufacturingProcess='SUB')
Content-Type: application/json
If-Match: *
X-CSRF-Token: <토큰>

{"KiloUnit":"2K"}
```

```
PATCH {base}Item(Plant='1100',Material='MAT001')
Content-Type: application/json
If-Match: *
X-CSRF-Token: <토큰>

{"DetailedItemGroupCode":"DIG09"}
```

### `$batch` — 헤더 품목그룹 변경 + 아이템도 함께 변경 (한 LUW)

헤더의 `ItemGroupCode`만 바꾸면 기존 아이템과 연결이 끊깁니다. 아이템도 같은 changeset에서 새 값으로 바꾸세요.

```
--batch_1
Content-Type: multipart/mixed; boundary=changeset_1

--changeset_1
Content-Type: application/http
Content-Transfer-Encoding: binary
Content-ID: 1

PATCH Header(CompanyCode='1000',ClassLevel1='SS50',ClassLevel2='SS5020',ClassLevel3='SMOC0203',ManufacturingProcess='SUB') HTTP/1.1
Content-Type: application/json
If-Match: *

{"ItemGroupCode":"BG004","KiloUnit":"2K"}
--changeset_1
Content-Type: application/http
Content-Transfer-Encoding: binary
Content-ID: 2

PATCH Item(Plant='1100',Material='MAT001') HTTP/1.1
Content-Type: application/json
If-Match: *

{"ItemGroupCode":"BG004"}
--changeset_1
Content-Type: application/http
Content-Transfer-Encoding: binary
Content-ID: 3

PATCH Item(Plant='1100',Material='MAT002') HTTP/1.1
Content-Type: application/json
If-Match: *

{"ItemGroupCode":"BG004","DetailedItemGroupCode":"DIG05"}
--changeset_1--
--batch_1--
```

## 확인할 점

- **아이템의 헤더 연결 값**: 이제 화면이 `CompanyCode`, `ItemGroupCode`를 직접 보냅니다. 값이 헤더와 다르면 엉뚱한 품목그룹에 붙습니다.
  같은 changeset에서 막 만든 헤더는 아직 DB에 없어서, 아이템 validation에서 "헤더가 있는지"를 DB로 확인하면 잘못 실패합니다. 그래서 헤더 존재 확인은 넣지 않았습니다. 화면에서 헤더 값을 그대로 복사해 넣도록 맞추세요.
- **아이템 중복**: 같은 플랜트·자재를 다시 `POST`하면 프레임워크 기본 오류로 거절됩니다. SaveAll 버전처럼 "이미 품목그룹 ○○에 속해 있습니다" 메시지가 필요하면 아이템 validation에 DB 확인을 추가하세요.
- **헤더 ItemGroupCode 수정**: 바꾸면 기존 아이템과 연결이 끊깁니다. 아이템의 `ItemGroupCode`도 같은 changeset에서 PATCH하세요 (위 `$batch` 예시). 막으려면 헤더 BDEF에서 `readonly : update`로 바꾸세요.
- **아이템 ItemGroupCode 수정** [수정 #10]: 바꾼 값에 해당하는 헤더(같은 CompanyCode + ItemGroupCode)가 있는지는 확인하지 않습니다. 필요하면 아이템 validation에 `field ItemGroupCode` 트리거로 헤더 존재 체크를 추가하세요. 같은 changeset에서 헤더를 새로 만들거나 바꾸는 경우에는 DB에 아직 반영되지 않아 실패할 수 있습니다.
- **헤더 삭제**: 아이템은 자동으로 지워지지 않습니다. 같은 changeset에 아이템 `DELETE`도 함께 넣으세요.

## 활성화 순서

1. 테이블 2개 → Base 뷰 2개 → 루트 뷰 2개 (함께)
2. BDEF 2개 → behavior pool Local Types 교체
3. Service Definition → Service Binding(OData V4 - Web API, **새 이름, 올바른 CTS 요청**) → Publish
