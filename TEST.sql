DECLARE @json NVARCHAR(MAX) = N'{"OrderID": 12345, "Customer": {"Name": "Kim", "Level": "VIP"}, "Items": [{"Prod": "Mouse", "Price": 30000}, {"Prod": "Keyboard", "Price": 50000}]}';

-- 기존 방식도 동작
SELECT dbo.JSON_VALUE(@json, 'Customer.Name') AS CustomerName; 
-- 결과: 'Kim'

-- 배열 접근 (새로운 [0] 표기법)
SELECT dbo.JSON_VALUE(@json, 'Items[0].Prod') AS FirstProduct;
-- 결과: 'Mouse'

SELECT dbo.JSON_VALUE(@json, 'Items[1].Price') AS SecondPrice;
-- 결과: '50000'
