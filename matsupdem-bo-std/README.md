# Material Supplier Demand Master RAP BO — 표준 CRUD 버전

`matsupdem-bo/`(SaveAll + abstract entity 버전)과 **같은 기능**을, abstract entity 없이 RAP 표준 CRUD로 만든 버전입니다.
Status(C/U/D)를 필드로 받지 않고 **HTTP 메서드로 구분**하고, 여러 행은 **`$batch` changeset 하나**로 묶어 한 LUW로 처리합니다.

> 오브젝트 이름이 SaveAll 버전과 같습니다. 시스템에는 **둘 중 하나만** 올리세요.
> `SupplyRatio`, `Remark`는 예시 필드이고, 키는 `CompanyCode, Material, Supplier, GoodsSupplier`입니다.

## 폴더 구조

| 폴더 | 내용 |
|---|---|
| `01_cds` | 저장 BO 루트 `ZMRMD_R_MatSupDemMasterSave` (00410), projection (SaveAll 버전과 동일) |
| `02_bdef` | 인터페이스 BDEF (`create/update/delete` + validation), projection BDEF |
| `03_classes` | Behavior pool: `lhc_matsup`(validation), `lsc_matsup`(00420 저장, SaveAll 버전과 동일) |
| `04_service` | Service Definition |

## SaveAll 버전과 다른 점

| | SaveAll 버전 | 표준 CRUD 버전 (이 폴더) |
|---|---|---|
| Status 전달 | 행마다 `Status` 필드 | HTTP 메서드 (POST / PATCH / DELETE) |
| 여러 행 한 번에 | JSON 한 번 | `$batch` changeset 하나 |
| abstract entity | 필요 | **없음** |
| CRUD | `internal` | 공개 (`use create/update/delete`) |
| 필수·중복·유효성 체크 | SaveAll 안에서 | `validateOnCreate` (on save, create) |
| U 대상 제한 | SaveAll에서 두 필드만 UPDATE | 키는 `readonly : update`라 PATCH로 바꿀 수 없음 |
| U/D 대상이 없을 때 | 사전 체크에서 오류 메시지 | 프레임워크가 404(not found)로 실패 |
| 00420 저장 | `save_modified` | **동일** |

## Status → 요청 매핑

| Status | 요청 |
|---|---|
| C | `POST MatSupSave` + JSON 본문 |
| U | `PATCH MatSupSave(CompanyCode='..',Material='..',Supplier='..',GoodsSupplier='..')` + 바꿀 필드만 |
| D | `PATCH MatSupSave(...)` + `{"DeletionIndicator": true}` (물리 삭제 없음, `delete` 비활성화) |

## `$batch` 호출 예시 (multipart)

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

POST MatSupSave HTTP/1.1
Content-Type: application/json

{"CompanyCode":"1000","Material":"MAT001","Supplier":"V001","GoodsSupplier":"V002","SupplyRatio":30.00,"Remark":"신규"}
--changeset_1
Content-Type: application/http
Content-Transfer-Encoding: binary
Content-ID: 2

PATCH MatSupSave(CompanyCode='1000',Material='MAT002',Supplier='V001',GoodsSupplier='V003') HTTP/1.1
Content-Type: application/json
If-Match: *

{"SupplyRatio":50.00,"Remark":"비율 변경"}
--changeset_1
Content-Type: application/http
Content-Transfer-Encoding: binary
Content-ID: 3

PATCH MatSupSave(CompanyCode='1000',Material='MAT003',Supplier='V004',GoodsSupplier='V004') HTTP/1.1
Content-Type: application/json
If-Match: *

{"DeletionIndicator":true}
--changeset_1--
--batch_1--
```

- **changeset 안의 요청은 한 트랜잭션**입니다. 하나라도 실패하면 changeset 전체가 롤백됩니다.
- 줄바꿈은 **CRLF**여야 하고, 헤더와 본문 사이에 **빈 줄**이 필요합니다. 형식이 조금만 틀려도 400 오류가 납니다.
- ETag를 쓰지 않아 `If-Match: *`로 보냅니다.
- 시스템에 따라 JSON 형식 `$batch`(`Content-Type: application/json`, `"requests": [...]`)도 지원합니다. 지원 여부는 직접 확인하세요.

## 소프트 삭제

- `delete`를 BDEF와 projection에서 뺐습니다. 삭제는 `PATCH`로 `DeletionIndicator`를 `true`로 바꿉니다. 데이터는 그대로 남습니다.
- `validateOnUpdate`: DB에서 이미 삭제 상태인 데이터는 수정·재삭제를 막습니다.
- `validateOnCreate`: 삭제 상태로 생성할 수 없고, 삭제된 데이터와 같은 키로 재등록할 수 없습니다.
- 조회 화면에서 삭제된 데이터를 빼려면 `$filter=DeletionIndicator eq false`를 쓰세요.

## 유효성 체크 (validateOnCreate)

| 순서 | 체크 | 메시지 |
|---|---|---|
| 1 | 필수 입력 (키 4개) | `[필드명] is required.` |
| 2 | 00410 중복 | `이미 등록된 데이터입니다 (...)` |
| 3 | `I_CompanyCode` | `[CompanyCode] <값> does not exist.` |
| 3 | `I_Product` | `[Material] <값> does not exist.` |
| 3 | `I_Supplier` | `[Supplier] <값> does not exist.` / `[GoodsSupplier] <값> does not exist.` |

생성(POST)할 때만 실행됩니다. 키는 수정할 수 없어서 PATCH/DELETE에서는 다시 체크하지 않습니다.

## 생성/변경 일시·사용자

- 00410: 루트 뷰에 `CreatedDate/CreatedTime/CreatedBy`, `ChangedDate/ChangedTime/ChangedBy`를 추가해 ERDAT/ERZET/ERNAM, AEDAT/AEZET/AENAM에 매핑했습니다.
  값은 determination `setCreateStamp`(생성), `setChangeStamp`(SupplyRatio·Remark 변경 시)가 서버 시스템 시간과 로그인 사용자로 채웁니다.
- 00420: `save_modified`에서 C/U 모두 최종 상태를 `READ ENTITIES`로 읽어 **로그 행으로 INSERT**합니다(한 번의 FOR로 처리). D는 삭제지시자 공백인 로그 행에 삭제 시각·사용자와 'X'를 기록합니다.
- 화면 표시용 `CreatedTimeStamp`, `ChangedTimeStamp`는 계산 필드(UTC)입니다.

## 활성화 순서

1. 저장 BO 루트 뷰 → projection 뷰
2. 인터페이스 BDEF → Quick Fix(Ctrl+1)로 behavior pool 생성 → Local Types 교체
3. projection BDEF
4. Service Definition → Service Binding(OData V4 - Web API, **새 이름, 올바른 CTS 요청**) → Publish

## 확인할 점 (TODO)

- `ZMRMD_I_ZTMRMD00410` 필드명, BDEF `mapping for` 오른쪽 컬럼명
- 00420 테이블명과 컬럼명 (`save_modified`)
- 자재·공급업체 번호 형식 (앞자리 0 포함 내부 형식인지)
