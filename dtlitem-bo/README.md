# Detailed Item Group Mng / User RAP BO

세부품목그룹(Mng)과 담당자(User)를 **SaveAll action 하나**로, 행마다 받은 `Status`(C/U/D)에 따라 저장합니다.
Mng–User는 **composition(부모–자식) 한 BO**라서 하나의 LUW로 처리되고, 하나라도 실패하면 전체가 롤백됩니다.

> 이름, 타입·길이, 테이블/컬럼명은 예시입니다. 코드의 `TODO` 위치를 실제 값으로 바꾸세요.

## 주신 뷰를 그대로 쓰지 않은 이유

`ZMRMD_I_DetailedItemMngSave`, `ZMRMD_I_DetailedItemUserSave`는 BO 루트/자식으로 쓸 수 없습니다.

- BO 뷰는 **파라미터(`P_Gubun`)를 가질 수 없습니다.**
- `Status`는 DB에 없는 값이라 **키로 둘 수 없습니다** (managed 저장, 잠금, 키 매핑이 모두 DB 키 기준).

그래서 BO는 원천 뷰(`ZMRMD_I_ZTMRMD00440/00441`) 기준으로 만들고, `Status`는 **SaveAll의 deep 파라미터 행마다** 받습니다.
DB에 저장되지 않는다는 조건도 그대로 지켜집니다.

주신 뷰를 조회용으로 계속 쓴다면 아래 문법도 함께 고치세요.
`ZMRMD-I_` → `ZMRMD_I_`, `cast( ... , as` → `cast( ... as`, `dat_tims_to_tstmp` → `dats_tims_to_tstmp`, 둥근 따옴표 `‘ ’` → `' '`.

## 폴더 구조

| 폴더 | 내용 |
|---|---|
| `01_cds` | BO 루트 `ZMRMD_R_DtlItemMng`, 자식 `ZMRMD_R_DtlItemUser`, projection 2개 |
| `02_abstract` | SaveAll deep 파라미터 (요청 루트 + Mng 행 + User 행) 와 abstract BDEF |
| `03_bdef` | 인터페이스 BDEF, projection BDEF |
| `04_classes` | Behavior pool (`*.locals_imp.abap`은 Local Types 탭) |
| `05_service` | Service Definition |

## 설계 포인트

- **create/update/delete는 모두 `internal`** 입니다. 표준 POST/PATCH/DELETE로 규칙(하위 존재 시 삭제 금지 등)을 우회할 수 없고, 저장은 SaveAll로만 됩니다.
- **사전 체크 → EML 실행** 순서입니다. 사전 체크에서 오류가 하나라도 있으면 아무것도 바꾸지 않고 실패합니다.
- EML 순서: **User 삭제 → Mng 생성·수정 + User 생성 → Mng 삭제**.
- 생성/변경 일시·사용자는 determination이 서버 시스템 시간과 로그인 사용자로 채웁니다.
  `CreatedTimeStamp`, `ChangedTimeStamp`는 화면 표시용 계산 필드입니다.

## Status 규칙

### Mng (세부품목그룹)

| Status | 동작 | 막는 경우 |
|---|---|---|
| C | 생성 (CompanyCode, ItemGroupCode, DetailedItemGroupCode, DetailedItemGroupName, Remark) | 이미 존재 |
| U | **품목명, Remark만** 수정 | 존재하지 않음 |
| D | 삭제 | 존재하지 않음 / **하위 담당자가 남는 경우** |

"하위 담당자가 남는다" = DB에 있는 담당자 중 **같은 요청에서 D로 함께 지우지 않는 것**이 있거나, 같은 요청에서 그 아래로 담당자를 C로 추가하려는 경우입니다.
같은 요청에서 담당자를 전부 D로 보내면 Mng도 함께 삭제할 수 있습니다.

### User (담당자 사번)

| Status | 동작 | 막는 경우 |
|---|---|---|
| C | 생성. 상위 Mng가 기존에 있거나 **같은 요청에서 C로 생성**되면 됨 | 상위 Mng 없음 / 이미 등록 |
| D | 조건 없이 삭제 | 없음 (DB에 없으면 그냥 넘어감) |
| U | 허용 안 함 (사번은 키) | 항상 |

## 유효성 체크 위치 (주석만 있음)

`zbp_mrmd_r_dtlitemmng.clas.locals_imp.abap`에서 `[유효성 체크 위치 #번호]`로 검색하세요.

| 번호 | 대상 | 위치 |
|---|---|---|
| #1 | ItemGroupCode | SaveAll → 2. Mng 행 처리 → `WHEN c_status-create` |
| #2 | DetailedItemGroupCode | SaveAll → 2. Mng 행 처리 → `WHEN c_status-create` |
| #3 | UserID (담당자 사번) | SaveAll → 3. User 행 처리 → `WHEN c_status-create` |

체크를 넣을 때는 실패 메시지를 `lt_msg`에 추가하고, 바로 아래의 "생성 대상 추가"는 건너뛰면 됩니다.
`lt_msg`가 비어 있지 않으면 4단계에서 전체가 실패 처리됩니다.

## 호출 예시

```
POST {base}Mng/com.sap.gateway.srvd_a2x.<서비스>.v0001.SaveAll
Content-Type: application/json
X-CSRF-Token: <토큰>
```

**기존 Mng에 담당자만 추가**
```json
{
  "Dummy": "",
  "_Mng": [],
  "_User": [
    { "Status": "C", "CompanyCode": "1000", "ItemGroupCode": "BG003", "DetailedItemGroupCode": "DIG01", "UserID": "E0001" }
  ]
}
```

**Mng 생성 + 그 아래 담당자 생성 + 다른 Mng 수정**
```json
{
  "Dummy": "",
  "_Mng": [
    { "Status": "C", "CompanyCode": "1000", "ItemGroupCode": "BG003", "DetailedItemGroupCode": "DIG02",
      "DetailedItemGroupName": "세부그룹2", "Remark": "" },
    { "Status": "U", "CompanyCode": "1000", "ItemGroupCode": "BG003", "DetailedItemGroupCode": "DIG01",
      "DetailedItemGroupName": "이름 변경", "Remark": "비고 변경" }
  ],
  "_User": [
    { "Status": "C", "CompanyCode": "1000", "ItemGroupCode": "BG003", "DetailedItemGroupCode": "DIG02", "UserID": "E0002" }
  ]
}
```

**담당자를 모두 지우고 Mng 삭제**
```json
{
  "Dummy": "",
  "_Mng":  [ { "Status": "D", "CompanyCode": "1000", "ItemGroupCode": "BG003", "DetailedItemGroupCode": "DIG01" } ],
  "_User": [ { "Status": "D", "CompanyCode": "1000", "ItemGroupCode": "BG003", "DetailedItemGroupCode": "DIG01", "UserID": "E0001" } ]
}
```

정확한 action 이름과 파라미터 형태는 `{base}$metadata`의 `<Action Name="SaveAll">`에서 확인하세요.

## 활성화 순서

1. 루트 뷰 + 자식 뷰 (composition으로 서로 참조 → **함께** 활성화)
2. projection 뷰 2개 (함께)
3. abstract entity 3개 + abstract BDEF (함께)
4. 인터페이스 BDEF → Quick Fix(Ctrl+1)로 behavior pool 생성 → Local Types 교체
5. projection BDEF
6. Service Definition → Service Binding(OData V4 - Web API, **새 이름, 올바른 CTS 요청**) → Publish

## 확인할 점 (TODO)

- 원천 뷰(`ZMRMD_I_ZTMRMD00440/00441`)의 **필드명**이 루트 뷰에 쓴 이름과 같은지
- BDEF의 `persistent table` 테이블명과 `mapping for` **오른쪽 컬럼명**
- abstract entity 필드 **타입·길이**가 테이블과 같은지 (`$metadata`의 MaxLength로 확인 가능)
- 테이블에 `_LO`(로컬 일시)나 시간대 필드가 있다면 determination에 추가
- 루트 abstract entity의 `Dummy`는 필드가 하나도 없으면 활성화가 안 될 수 있어 둔 자리입니다. 없어도 활성화되면 지워도 됩니다.
