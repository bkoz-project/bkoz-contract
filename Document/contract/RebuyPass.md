
# RebuyPass 스마트 컨트랙트 함수 설명서

## 개요
이 문서는 `RebuyPass` 스마트 컨트랙트의 주요 함수에 대한 설명을 제공하여 웹 개발자들이 이를 이해하고 프론트엔드 애플리케이션과 상호작용할 수 있도록 돕습니다. 이 컨트랙트는 Rebuy 패스를 관리하고 판매하는 기능을 포함합니다.

## 컨트랙트 이름: `RebuyPass`

### 함수 목록
1. [패스 가격 조회 함수](#패스-가격-조회-함수)
2. [패스 구매 함수](#패스-구매-함수)
3. [패스 상태 확인 함수](#패스-상태-확인-함수)

### 패스 가격 조회 함수
#### 1. `getRebuyPassPrice(address tokenAddress)`
- **설명**: 리바이 패스의 가격을 반환합니다.
- **입력 파라미터**:
  - `tokenAddress (address)`: 토큰 주소
- **출력 값**:
  - `uint256`: 리바이 패스 가격
- **예외 사항**:
  - `Token not supported`: 지원되지 않는 토큰일 때 발생합니다.
- **사용 예시**:
  ```javascript
  const price = await contract.methods.getRebuyPassPrice(tokenAddress).call();
  ```

### 패스 구매 함수
#### 2. `buyRebuyPass(address _tokenAddress)`
- **설명**: 리바이 패스를 구매합니다.
- **입력 파라미터**:
  - `_tokenAddress (address)`: 토큰 주소
- **예외 사항**:
  - `Already owns a valid Rebuy Pass`: 이미 유효한 리바이 패스를 소유하고 있을 때 발생합니다.
  - `Token not supported`: 지원되지 않는 토큰일 때 발생합니다.
  - `Token Transfer failed`: 토큰 전송 실패 시 발생합니다.
- **사용 예시**:
  ```javascript
  await contract.methods.buyRebuyPass(tokenAddress).send({ from: userAddress });
  ```

### 패스 상태 확인 함수
#### 3. `hasValidRebuyPass(address user)`
- **설명**: 사용자가 유효한 리바이 패스를 소유하고 있는지 확인합니다.
- **입력 파라미터**:
  - `user (address)`: 사용자 주소
- **출력 값**:
  - `bool`: 유효한 리바이 패스를 소유하고 있는지 여부
- **사용 예시**:
  ```javascript
  const hasRebuyPass = await contract.methods.hasValidRebuyPass(userAddress).call();
  ```

#### 4. `getRemainingRebuyPass(address user)`
- **설명**: 사용자의 리바이 패스 남은 기간을 반환합니다.
- **입력 파라미터**:
  - `user (address)`: 사용자 주소
- **출력 값**:
  - `uint256`: 리바이 패스 남은 기간 (초 단위)
- **사용 예시**:
  ```javascript
  const remainingTime = await contract.methods.getRemainingRebuyPass(userAddress).call();
  ```

#### 5. `revokeRebuyPass(address user)`
- **설명**: 사용자의 리바이 패스를 해제합니다.
- **입력 파라미터**:
  - `user (address)`: 사용자 주소
- **사용 예시**:
  ```javascript
  await contract.methods.revokeRebuyPass(userAddress).send({ from: adminAddress });
  ```

이 문서를 통해 웹 개발자는 `RebuyPass` 스마트 컨트랙트와 효과적으로 상호작용할 수 있습니다. 각 함수의 사용 예시는 JavaScript를 사용하여 Web3.js 또는 이더리움과 상호작용하는 방법을 보여줍니다.
