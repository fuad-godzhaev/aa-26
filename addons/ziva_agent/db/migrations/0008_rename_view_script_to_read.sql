-- Custom SQL migration file, put your code below! --

UPDATE parts
SET tool_name = 'read'
WHERE tool_name = 'view_script';