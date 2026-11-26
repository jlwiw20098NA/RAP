# Detailed Item Group Mng / User RAP BO — 표준 HTTP 버전

`dtlitem-bo/`(SaveAll + Status C/U/D 버전)와 같은 BO를 **표준 POST / PATCH / DELETE**로 저장하도록 바꾼 버전입니다.
SaveAll action과 abstract entity(`ZMRMD_A_DtlSaveReq/Mng/User`)가 없습니다.

> 오브젝트 이름이 `dtlitem-bo`와 같습니다. 시스템에는 **둘 중 하나만** 올리세요.
> 이름, 타입·길이, 테이블/컬럼명은 예시입니다. 코드의 `TODO` 위치를 실제 값으로 바꾸세요.
> 바뀐 곳은 코드에서 `[표준 #번호]`로 검색하세요.

## 폴더 구조

| 폴더 | 내용 |
|---|---|
| `01_cds` | 루트·자식 뷰, projection 2개 (주석 한 줄 외 변경 없음) |
| `02_bdef` | 인터페이스 BDEF, projection BDEF |
| `03_classes` | Behavior pool (`*.locals_imp.abap`은 Local Types 탭) |
| `04_service` | Service Definition (변경 없음) |

## 바뀐 곳

| 번호 | 위치 | 내용 |
|---|---|---|
| #1 | `ZMRMD_R_DtlItemMng` 주석 | Status 대신 HTTP 메서드로 구분 |
| #2 | BDEF 2개, behavior pool | `SaveAll` 제거. create/update/delete와 `_User { create; }`를 internal → 공개. 키에 `mandatory : create` 추가. 권한을 `%create/%update/%delete`로 |
| #3 | BDEF `delete ( precheck )`, `precheck_delete` | "하위 담당자가 남으면 Mng 삭제 금지" |
| #4 | `validateOnCreate` (Mng, User) | ItemGroupCode 공통코드 체크(구현됨), 유효성 체크 위치 #2·#3(주석) |
| #5 | BDEF | 담당자 생성은 Mng를 통해서만 (`POST Mng(...)/_User` 또는 deep insert) |
| #6 | BDEF, `validateOnCreate` 주석 | `DetailedItemGroupCode`를 `mandatory`에서 제외 → 빈 값(`''`)으로 저장 가능 |

### DetailedItemGroupCode 빈 값 [표준 #6]

- 생성: 본문에 `"DetailedItemGroupCode": ""`를 넣거나 필드를 빼면 빈 값으로 저장됩니다.
- 수정·삭제·담당자 추가: URL에 `DetailedItemGroupCode=''`
  예: `PATCH Mng(CompanyCode='1000',ItemGroupCode='BG003',DetailedItemGroupCode='')`
- 빈 값도 키 값이라 같은 `CompanyCode + ItemGroupCode`에 **빈 값 행은 하나만** 가능합니다.
- 나중에 실제 코드로 바꿀 수 없습니다 (키, `readonly : update`). 삭제 후 다시 생성하세요.

## SaveAll 규칙이 어디로 갔는지

### Mng (세부품목그룹)

| SaveAll | 표준 버전 | 막는 주체 |
|---|---|---|
| C 생성 | `POST Mng` | |
| C인데 이미 존재 | 중복 키 오류 | 프레임워크 |
| C의 ItemGroupCode 공통코드 체크 | `validateOnCreate` (저장 시) | validation |
| U (품목명, Remark만) | `PATCH Mng(...)` — 키는 `readonly : update` | BDEF |
| U인데 없음 | 404 | 프레임워크 |
| D 삭제 | `DELETE Mng(...)` | |
| D인데 없음 | 404 | 프레임워크 |
| D인데 하위 담당자 남음 | `precheck_delete`가 거절 | precheck |

### User (담당자)

| SaveAll | 표준 버전 | 막는 주체 |
|---|---|---|
| C 생성 | `POST Mng(...)/_User` | |
| C인데 상위 Mng 없음 | 404 (부모 경로가 없음) | 프레임워크 |
| C인데 이미 등록 | 중복 키 오류 | 프레임워크 |
| D 삭제 | `DELETE User(...)` | |
| D인데 없음 → 그냥 넘어감 | **404 오류** (달라진 점) | 프레임워크 |
| U 허용 안 함 | update가 internal이라 PATCH 자체가 없음 | BDEF |

- **payload 안 중복**: 같은 키를 같은 changeset에서 두 번 POST하면 프레임워크가 두 번째를 중복으로 거절합니다.
- **사전 체크 후 일괄 실행**: SaveAll처럼 "먼저 다 확인하고 실행"하지는 않지만, changeset 하나가 한 LUW라서 하나라도 실패하면 전체가 롤백됩니다. 결과는 같습니다.
- **User D 없음**: SaveAll은 조용히 넘어갔지만 표준 DELETE는 404로 changeset 전체가 실패합니다. 화면에서 조회한 담당자만 DELETE하도록 하세요.

## 요청 형태

`{base}` = `.../sap/opu/odata4/sap/<바인딩>/srvd_a2x/sap/<서비스>/0001/`

| 작업 | 요청 | 본문 |
|---|---|---|
| Mng 생성 | `POST Mng` | 키 3개 + DetailedItemGroupName, Remark |
| Mng + 담당자 함께 생성 | `POST Mng` (deep insert) | 위 + `"_User": [ { "UserID": ".." } ]` |
| Mng 수정 | `PATCH Mng(CompanyCode='..',ItemGroupCode='..',DetailedItemGroupCode='..')` | DetailedItemGroupName, Remark 중 바꿀 것만 |
| Mng 삭제 | `DELETE Mng(...)` | 없음 |
| 기존 Mng에 담당자 추가 | `POST Mng(...)/_User` | `{ "UserID": ".." }` (부모 키는 자동) |
| 담당자 삭제 | `DELETE User(CompanyCode='..',ItemGroupCode='..',DetailedItemGroupCode='..',UserID='..')` | 없음 |

- PATCH, DELETE에는 `If-Match: *`를 붙이세요 (ETag 없음).
- 담당자 POST 본문에는 **UserID만** 넣습니다. CompanyCode 등은 readonly라 넣으면 오류가 납니다.

## `$batch` 예시

공통 헤더:
```
POST {base}$batch
Content-Type: multipart/mixed; boundary=batch_1
Accept: multipart/mixed
X-CSRF-Token: <토큰>
```

### 1. Mng 생성 + 그 아래 담당자 2명 (deep insert) + 다른 Mng 수정

```
--batch_1
Content-Type: multipart/mixed; boundary=changeset_1

--changeset_1
Content-Type: application/http
Content-Transfer-Encoding: binary
Content-ID: 1

POST Mng HTTP/1.1
Content-Type: application/json

{"CompanyCode":"1000","ItemGroupCode":"BG003","DetailedItemGroupCode":"DIG02","DetailedItemGroupName":"세부그룹2","Remark":"","_User":[{"UserID":"E0002"},{"UserID":"E0003"}]}
--changeset_1
Content-Type: application/http
Content-Transfer-Encoding: binary
Content-ID: 2

PATCH Mng(CompanyCode='1000',ItemGroupCode='BG003',DetailedItemGroupCode='DIG01') HTTP/1.1
Content-Type: application/json
If-Match: *

{"DetailedItemGroupName":"이름 변경","Remark":"비고 변경"}
--changeset_1--
--batch_1--
```

### 2. 기존 Mng에 담당자 추가 + 다른 담당자 삭제

```
--batch_1
Content-Type: multipart/mixed; boundary=changeset_1

--changeset_1
Content-Type: application/http
Content-Transfer-Encoding: binary
Content-ID: 1

POST Mng(CompanyCode='1000',ItemGroupCode='BG003',DetailedItemGroupCode='DIG01')/_User HTTP/1.1
Content-Type: application/json

{"UserID":"E0004"}
--changeset_1
Content-Type: application/http
Content-Transfer-Encoding: binary
Content-ID: 2

DELETE User(CompanyCode='1000',ItemGroupCode='BG003',DetailedItemGroupCode='DIG01',UserID='E0001') HTTP/1.1
If-Match: *

--changeset_1--
--batch_1--
```

### 3. 담당자를 모두 지우고 Mng 삭제

**순서가 중요합니다.** 담당자 DELETE가 먼저, Mng DELETE가 마지막이어야 precheck를 통과합니다.

```
--batch_1
Content-Type: multipart/mixed; boundary=changeset_1

--changeset_1
Content-Type: application/http
Content-Transfer-Encoding: binary
Content-ID: 1

DELETE User(CompanyCode='1000',ItemGroupCode='BG003',DetailedItemGroupCode='DIG01',UserID='E0001') HTTP/1.1
If-Match: *

--changeset_1
Content-Type: application/http
Content-Transfer-Encoding: binary
Content-ID: 2

DELETE Mng(CompanyCode='1000',ItemGroupCode='BG003',DetailedItemGroupCode='DIG01') HTTP/1.1
If-Match: *

--changeset_1--
--batch_1--
```

형식 규칙: `boundary=changeset_1` 줄 다음, 각 파트의 `Content-ID` 다음, 안쪽 헤더 다음에 **빈 줄**이 하나씩 있어야 합니다. 빠지면 그 파트가 무시됩니다.

## 활성화 순서

1. 기존 SaveAll 버전이 시스템에 있으면: projection BDEF에서 `use action SaveAll` 제거 → 인터페이스 BDEF 교체 → Local Types 교체 → abstract BDEF·entity 3개 삭제
2. 새로 올리는 경우: 루트 + 자식 뷰(함께) → projection 뷰 2개(함께) → 인터페이스 BDEF → Quick Fix로 behavior pool 생성 → Local Types 교체 → projection BDEF
3. Service Definition → Service Binding(OData V4 - Web API) → Publish
   - 바인딩이 이미 publish돼 있으면 BDEF 변경 뒤 **Unpublish → Publish**로 `$metadata`를 새로 받으세요.

## 확인할 점

- **deep insert**: `POST Mng`에 `_User`를 함께 넣는 방식은 composition이 있어서 동작합니다. 안 되는 릴리스라면 Mng POST 다음에 `POST $1/_User`(Content-ID 참조) 또는 키를 적은 `POST Mng(...)/_User`를 같은 changeset에 넣으세요.
- **precheck와 요청 순서**: precheck는 그 시점의 트랜잭션 버퍼를 읽습니다. 같은 changeset에서 Mng DELETE가 담당자 DELETE보다 먼저 오면 거절됩니다.
- **validation 위치 #2, #3**은 주석만 있습니다. 실패 시 `failed-*`, `reported-*`에 넣는 예시가 주석에 있습니다.
- 원천 뷰 필드명, 테이블명, `mapping for` 컬럼명은 SaveAll 버전과 같은 TODO입니다.
