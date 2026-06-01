-- Custom SQL migration file, put your code below! --

UPDATE parts
SET tool_name = 'create_file'
WHERE tool_name = 'create_script';