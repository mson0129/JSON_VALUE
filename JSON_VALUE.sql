CREATE FUNCTION dbo.JSON_VALUE (
    @json NVARCHAR(MAX),
    @path NVARCHAR(MAX)
)
RETURNS NVARCHAR(MAX)
AS
BEGIN
    DECLARE @Result NVARCHAR(MAX);
    
    -- $. 표시 제거
    SET @path = REPLACE(@path, '$.', '');
    
    -- [0] 형식을 .0 형식으로 변환
    -- [숫자] 패턴을 찾아서 .숫자로 변경
    DECLARE @i INT = 1;
    WHILE CHARINDEX('[', @path) > 0
    BEGIN
        DECLARE @startPos INT = CHARINDEX('[', @path);
        DECLARE @endPos INT = CHARINDEX(']', @path, @startPos);
        
        IF @endPos > @startPos
        BEGIN
            DECLARE @indexValue NVARCHAR(10) = SUBSTRING(@path, @startPos + 1, @endPos - @startPos - 1);
            
            -- [n]을 .n으로 변환
            SET @path = STUFF(@path, @startPos, @endPos - @startPos + 1, '.' + @indexValue);
        END
        ELSE
            BREAK;
            
        SET @i = @i + 1;
        IF @i > 100 BREAK; -- 무한루프 방지
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

    -- 계층적으로 탐색
    ;WITH HierarchySearch AS (
        -- 루트 노드부터 시작
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
        
        -- 자식 노드로 이동
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
           OR (ISNUMERIC(p.StepName) = 1 AND child.SequenceNo = (CASE WHEN ISNUMERIC(p.StepName) = 1 THEN CAST(p.StepName AS INT) + 1 ELSE -1 END))
    )
    SELECT TOP 1 @Result = StringValue 
    FROM HierarchySearch 
    ORDER BY StepLevel DESC;

    RETURN @Result;
END
GO
