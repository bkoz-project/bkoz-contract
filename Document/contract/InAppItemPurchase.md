
# InAppItemPurchase 스마트 컨트랙트 함수 설명서

## 개요
이 문서는 `InAppItemPurchase` 스마트 컨트랙트의 주요 함수에 대한 설명을 제공하여 웹 개발자들이 이를 이해하고 프론트엔드 애플리케이션과 상호작용할 수 있도록 돕습니다. 이 컨트랙트는 인앱 아이템을 관리하고 판매하는 기능을 포함합니다.

## 컨트랙트 이름: `InAppItemPurchase`

### 함수 목록
1. [아이템 가격 조회 함수](#아이템-가격-조회-함수)
2. [아이템 구매 함수](#아이템-구매-함수)
3. [아이템 관리 함수](#아이템-관리-함수)
4. [관리자 설정 함수](#관리자-설정-함수)

### 아이템 가격 조회 함수
#### 1. `getItemPrice(uint256 _itemId, address _tokenAddress)`
- **설명**: 특정 아이템의 가격을 반환합니다.
- **입력 파라미터**:
  - `_itemId (uint256)`: 아이템 ID
  - `_tokenAddress (address)`: 토큰 주소
- **출력 값**:
  - `uint256`: 아이템 가격
- **예외 사항**:
  - `Item does not exist`: 아이템이 존재하지 않을 때 발생합니다.
- **사용 예시**:
  ```javascript
  const price = await contract.methods.getItemPrice(itemId, tokenAddress).call();
  ```

### 아이템 구매 함수
#### 2. `purchaseItem(uint256 _itemId, address _tokenAddress)`
- **설명**: 특정 아이템을 구매합니다.
- **입력 파라미터**:
  - `_itemId (uint256)`: 아이템 ID
  - `_tokenAddress (address)`: 토큰 주소
- **예외 사항**:
  - `Item does not exist`: 아이템이 존재하지 않을 때 발생합니다.
  - `Invalid token address`: 유효하지 않은 토큰 주소일 때 발생합니다.
- **사용 예시**:
  ```javascript
  await contract.methods.purchaseItem(itemId, tokenAddress).send({ from: userAddress });
  ```

### 아이템 관리 함수
#### 3. `setItem(uint256 _itemId, address[] memory _tokenAddresses, uint256[] memory _prices)`
- **설명**: 새로운 아이템을 설정합니다.
- **입력 파라미터**:
  - `_itemId (uint256)`: 아이템 ID
  - `_tokenAddresses (address[])`: 토큰 주소 배열
  - `_prices (uint256[])`: 가격 배열
- **예외 사항**:
  - `Token address and price arrays must have the same length`: 토큰 주소 배열과 가격 배열의 길이가 같지 않을 때 발생합니다.
- **사용 예시**:
  ```javascript
  await contract.methods.setItem(itemId, tokenAddresses, prices).send({ from: adminAddress });
  ```

#### 4. `changeItemPrice(uint256 _itemId, address _tokenAddress, uint256 _newPrice)`
- **설명**: 특정 아이템의 가격을 변경합니다.
- **입력 파라미터**:
  - `_itemId (uint256)`: 아이템 ID
  - `_tokenAddress (address)`: 토큰 주소
  - `_newPrice (uint256)`: 새로운 가격
- **예외 사항**:
  - `Item does not exist`: 아이템이 존재하지 않을 때 발생합니다.
- **사용 예시**:
  ```javascript
  await contract.methods.changeItemPrice(itemId, tokenAddress, newPrice).send({ from: adminAddress });
  ```

#### 5. `removeItem(uint256 _itemId)`
- **설명**: 특정 아이템을 제거합니다.
- **입력 파라미터**:
  - `_itemId (uint256)`: 아이템 ID
- **예외 사항**:
  - `Item does not exist`: 아이템이 존재하지 않을 때 발생합니다.
- **사용 예시**:
  ```javascript
  await contract.methods.removeItem(itemId).send({ from: adminAddress });
  ```

### 관리자 설정 함수
#### 6. `changeDeveloperAddress(address _newDeveloper)`
- **설명**: 개발자 주소를 변경합니다.
- **입력 파라미터**:
  - `_newDeveloper (address)`: 새로운 개발자 주소
- **사용 예시**:
  ```javascript
  await contract.methods.changeDeveloperAddress(newDeveloperAddress).send({ from: adminAddress });
  ```

#### 7. `changeAdminSharePercentage(uint256 _newAdminSharePercentage)`
- **설명**: 관리자의 수익 분배 비율을 변경합니다.
- **입력 파라미터**:
  - `_newAdminSharePercentage (uint256)`: 새로운 수익 분배 비율 (0-100)
- **예외 사항**:
  - `Invalid percentage`: 유효하지 않은 비율일 때 발생합니다.
- **사용 예시**:
  ```javascript
  await contract.methods.changeAdminSharePercentage(newAdminSharePercentage).send({ from: adminAddress });
  ```

이 문서를 통해 웹 개발자는 `InAppItemPurchase` 스마트 컨트랙트와 효과적으로 상호작용할 수 있습니다. 각 함수의 사용 예시는 JavaScript를 사용하여 Web3.js 또는 이더리움과 상호작용하는 방법을 보여줍니다.
