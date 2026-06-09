USE [SalesAnalytics]
GO
/****** Object:  UserDefinedFunction [dbo].[JSON_VALUE]    Script Date: 2026-06-09 오전 9:57:57 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER FUNCTION [dbo].[JSON_VALUE] (
    @json NVARCHAR(MAX),
    @path NVARCHAR(MAX) -- 예: 'Customer.Name' 또는 'Items[0].Price'
)
RETURNS NVARCHAR(MAX)
AS
BEGIN
    DECLARE @Result NVARCHAR(MAX);
    DECLARE @LastStepName NVARCHAR(MAX);
    
    -- $. 표시 제거
    SET @path = REPLACE(@path, '$.', '');
    
    -- [0] 형식을 .0 형식으로 변환
    DECLARE @i INT = 1;
    WHILE CHARINDEX('[', @path) > 0
    BEGIN
        DECLARE @startPos INT = CHARINDEX('[', @path);
        DECLARE @endPos INT = CHARINDEX(']', @path, @startPos);
        
        IF @endPos > @startPos
        BEGIN
            DECLARE @indexValue NVARCHAR(10) = SUBSTRING(@path, @startPos + 1, @endPos - @startPos - 1);
            SET @path = STUFF(@path, @startPos, @endPos - @startPos + 1, '.' + @indexValue);
        END
        ELSE
            BREAK;
            
        SET @i = @i + 1;
        IF @i > 100 BREAK;
    END

    -- JSON을 한 번만 파싱하여 임시 테이블에 저장
    DECLARE @ParsedJSON TABLE (
        Element_ID INT,
        SequenceNo INT,
        Parent_ID INT,
        Object_ID INT,
        Name NVARCHAR(2000),
        StringValue NVARCHAR(MAX),
        ValueType VARCHAR(10)
    );
    
    INSERT INTO @ParsedJSON
    SELECT * FROM dbo.parseJSON(@json);

    -- 경로를 . 기준으로 분리하여 임시 테이블에 저장
    DECLARE @PathSteps TABLE (
        StepLevel INT,
        StepName NVARCHAR(MAX)
    );
    
    INSERT INTO @PathSteps
    SELECT 
        ROW_NUMBER() OVER(ORDER BY (SELECT NULL)) AS StepLevel,
        value AS StepName
    FROM dbo.STRING_SPLIT(@path, '.');

    -- [보정 추가] 마지막에 찾고자 하는 Key/속성명을 미리 확보
    SELECT TOP 1 @LastStepName = StepName FROM @PathSteps ORDER BY StepLevel DESC;

    -- 계층적으로 탐색
    ;WITH HierarchySearch AS (
        SELECT 
            h.Element_ID, 
            h.Parent_ID,
            h.Object_ID,
            h.Name, 
            h.StringValue, 
            h.ValueType,
            1 AS StepLevel
        FROM @ParsedJSON h
        JOIN @PathSteps p ON p.StepLevel = 1
        WHERE h.Name = p.StepName
        
        UNION ALL
        
        SELECT 
            child.Element_ID, 
            child.Parent_ID,
            child.Object_ID,
            child.Name, 
            child.StringValue,
            child.ValueType,
            parent.StepLevel + 1
        FROM HierarchySearch parent
        JOIN @ParsedJSON child ON child.Parent_ID = parent.Object_ID
        JOIN @PathSteps p ON p.StepLevel = parent.StepLevel + 1
        WHERE child.Name = p.StepName 
           OR (p.StepName NOT LIKE '%[^0-9]%' AND child.SequenceNo = (CASE WHEN p.StepName NOT LIKE '%[^0-9]%' THEN CAST(p.StepName AS INT) + 1 ELSE -1 END))
    )
    SELECT TOP 1 @Result = StringValue 
    FROM HierarchySearch 
    ORDER BY StepLevel DESC;

    -- [★ 음수 오류 최종 방어 코드 추가 ★]
    -- 추출된 결과가 숫자 형태인데, 원본 JSON 텍스트에서 "Key": -값 형태로 음수 부호가 존재한다면 마이너스를 강제로 붙여줌
    IF @Result IS NOT NULL AND @Result NOT LIKE '-%' AND @LastStepName IS NOT NULL
    BEGIN
        -- 원본 JSON에서 "보정대상Key"\s*:\s*-값 형태가 존재하는지 패턴 확인
        DECLARE @SearchPattern NVARCHAR(500) = '%"' + @LastStepName + '"%-%' + @Result + '%';
        
        -- 만약 원본에 마이너스 부호와 함께 매칭되는 구간이 있다면 음수로 강제 전환
        IF PATINDEX(@SearchPattern, @json) > 0
        BEGIN
            SET @Result = '-' + @Result;
        END
    END

    RETURN @Result;
END
GO
