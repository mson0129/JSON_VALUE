CREATE FUNCTION dbo.STRING_SPLIT (
    @string NVARCHAR(MAX),
    @separator CHAR(1)
)
RETURNS @output TABLE (value NVARCHAR(MAX))
AS
BEGIN
    -- Parsing using XML format.
    DECLARE @xml XML;
    
    -- Convert strings to XML nodes.
    SET @xml = CAST('<root><node>' + REPLACE(@string, @separator, '</node><node>') + '</node></root>' AS XML);

    -- Insert XML nodes as table rows.
    INSERT INTO @output (value)
    SELECT r.node.value('.', 'NVARCHAR(MAX)')
    FROM @xml.nodes('/root/node') AS r(node);

    RETURN;
END
