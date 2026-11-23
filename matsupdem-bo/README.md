# Material Supplier Demand Master RAP BO

화면이 조회 뷰(`ZMRMD_R_MatSupDemMaster`)로 데이터를 받아 수정한 뒤, 행마다 `Status`(C/U/D)를 붙여 **SaveAll** API로 보내면
`ZMRMD_R_MatSupDemMasterSave` BO가 00410을 저장하고, **같은 트랜잭션에서** 00420에 이력을 남깁니다.
하나라도 실패하면 00410, 00420 모두 저장되지 않습니다.

> `SupplyRatio`, `Remark`는 예시 필드입니다. 테이블/컬럼명, 타입은 코드의 `TODO` 위치를 실제 값으로 바꾸세요.
> 키는 실제와 같은 `CompanyCode, Material, Supplier, GoodsSupplier`입니다.

> 같은 기능을 abstract entity 없이 표준 CRUD + `$batch`로 만든 버전은 `../matsupdem-bo-std/`에 있습니다. 오브젝트 이름이 같으니 시스템에는 둘 중 하나만 올리세요.

## 폴더 구조

| 폴더 | 내용 |
|---|---|
| `01_cds` | 저장 BO 루트 `ZMRMD_R_MatSupDemMasterSave` (00410), projection |
| `02_abstract` | SaveAll deep 파라미터 (요청 루트 + 행) 와 abstract BDEF |
| `03_bdef` | 인터페이스 BDEF (`managed with additional save`), projection BDEF |
| `04_classes` | Behavior pool: `lhc_matsup`(SaveAll), `lsc_matsup`(00420 저장) |
| `05_service` | Service Definition |

조회 뷰 `ZMRMD_R_MatSupDemMaster`는 이미 있는 뷰라 여기 포함하지 않았습니다. 같은 API로 노출하려면 Service Definition의 주석을 해제하세요.

## 처리 흐름

```
POST SaveAll (행 목록, 행마다 Status)
  [SaveAll: 사전 체크 - DB 변경 없음]
   0. payload 안 키 중복
   1. 기존 00410 조회 (DB + 버퍼)
   2. 행마다
      - 필수 입력: CompanyCode, Material, Supplier, GoodsSupplier
      - C: 중복 체크 + 유효성 체크 (회사코드, 자재, 공급업체, 물품공급업체)
      - U: 존재 확인 → SupplyRatio, Remark 수정
      - D: 존재 확인 → 삭제
   3. 오류가 하나라도 있으면 전체 실패
   4. MODIFY ENTITIES (00410 버퍼 반영)
  [저장 단계]
   - managed가 00410 INSERT / UPDATE / DELETE
   - save_modified가 00420 처리
  → COMMIT 한 번
```

## Status 규칙

| Status | 00410 | 00420 | 막는 경우 |
|---|---|---|---|
| C | 생성 | **행 생성** (키 4개 + TimeStamp + 데이터, 삭제지시자 공백) | 키 중복 / 유효성 오류 |
| U | SupplyRatio, Remark 수정 | 유효한 행(삭제지시자 공백)의 **같은 필드 수정** | 데이터 없음 |
| D | 삭제 | 유효한 행에 **삭제지시자 'X'** | 데이터 없음 |

- 00420에는 Status 필드를 두지 않습니다.
- TimeStamp(`tzntstmps`)는 저장 시각(UTC)입니다.
- 삭제 후 같은 키로 다시 C하면 00420에 TimeStamp가 다른 새 행이 생기고, 이전 행은 'X'로 남습니다.
  그래서 U/D는 삭제지시자가 공백인 행만 대상으로 합니다.

## 유효성 체크

| 대상 | 조회 뷰 | 오류 메시지 |
|---|---|---|
| CompanyCode | `I_CompanyCode` | `[CompanyCode] <값> does not exist.` |
| Material | `I_Product` | `[Material] <값> does not exist.` |
| Supplier | `I_Supplier` | `[Supplier] <값> does not exist.` |
| GoodsSupplier | `I_Supplier` | `[GoodsSupplier] <값> does not exist.` |

- **C일 때만** 체크합니다. 키는 U/D에서 바뀌지 않기 때문입니다.
- 표준 뷰의 DCL(`#CHECK`) 때문에 권한이 없는 사용자에게 데이터가 안 보이는 문제를 피하려고 `WITH PRIVILEGED ACCESS`로 조회합니다.
- 한 요청 최대 10건 수준이라 행마다 `SELECT SINGLE`로 조회합니다.

## 호출 예시

```
POST {base}MatSupSave/com.sap.gateway.srvd_a2x.<서비스>.v0001.SaveAll
Content-Type: application/json
X-CSRF-Token: <토큰>
```

```json
{
  "Dummy": "",
  "_Row": [
    { "Status": "C", "CompanyCode": "1000", "Material": "MAT001", "Supplier": "V001", "GoodsSupplier": "V002",
      "SupplyRatio": 30.00, "Remark": "신규" },
    { "Status": "U", "CompanyCode": "1000", "Material": "MAT002", "Supplier": "V001", "GoodsSupplier": "V003",
      "SupplyRatio": 50.00, "Remark": "비율 변경" },
    { "Status": "D", "CompanyCode": "1000", "Material": "MAT003", "Supplier": "V004", "GoodsSupplier": "V004" }
  ]
}
```

정확한 action 이름과 파라미터 형태는 `{base}$metadata`의 `<Action Name="SaveAll">`에서 확인하세요.

## 생성/변경 일시·사용자

- 00410: 루트 뷰에 `CreatedDate/CreatedTime/CreatedBy`, `ChangedDate/ChangedTime/ChangedBy`를 추가해 ERDAT/ERZET/ERNAM, AEDAT/AEZET/AENAM에 매핑했습니다.
  값은 determination `setCreateStamp`(생성), `setChangeStamp`(SupplyRatio·Remark 변경 시)가 서버 시스템 시간과 로그인 사용자로 채웁니다.
- 00420: `save_modified`에서 같은 값을 기록합니다. C는 생성·변경 정보 그대로, U는 변경 정보를 갱신, D는 삭제 시각·사용자를 변경 정보에 기록하고 삭제지시자 'X'를 찍습니다.
- 화면 표시용 `CreatedTimeStamp`, `ChangedTimeStamp`는 계산 필드(UTC)입니다.

## 활성화 순서

1. 저장 BO 루트 뷰 → projection 뷰
2. abstract entity 2개 + abstract BDEF (함께)
3. 인터페이스 BDEF → Quick Fix(Ctrl+1)로 behavior pool 생성 → Local Types 교체
4. projection BDEF
5. Service Definition → Service Binding(OData V4 - Web API, **새 이름, 올바른 CTS 요청**) → Publish

## 확인할 점 (TODO)

- `ZMRMD_I_ZTMRMD00410` 필드명, BDEF `persistent table`과 `mapping for` 오른쪽 컬럼명
- 00420 테이블명과 컬럼명 (`save_modified` 안의 DML)
- abstract entity 필드 타입·길이 (`matnr`, `lifnr` 등)
- **자재·공급업체 번호 형식**: `I_Product`, `I_Supplier`는 내부 형식(앞자리 0 포함)으로 저장됩니다.
  화면이 `1001`처럼 0 없이 보내면 존재하는데도 "does not exist"가 날 수 있습니다. 화면에서 내부 형식으로 보내거나, 체크 전에 변환하세요.
- 기존 00410 데이터 중 00420에 유효한 행이 없는 데이터는 U/D 때 00420이 갱신되지 않습니다 (0건 UPDATE).
