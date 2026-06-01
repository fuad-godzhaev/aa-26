PRAGMA foreign_keys=OFF;--> statement-breakpoint
CREATE TABLE `__new_parts` (
	`id` text PRIMARY KEY NOT NULL,
	`message_id` text NOT NULL,
	`type` text NOT NULL,
	`order` integer NOT NULL,
	`created_at` text DEFAULT CURRENT_TIMESTAMP,
	`updatedAt` text DEFAULT CURRENT_TIMESTAMP NOT NULL,
	`text_text` text,
	`reasoning_text` text,
	`file_media_type` text,
	`file_filename` text,
	`file_url` text,
	`source_url_source_id` text,
	`source_url_url` text,
	`source_url_title` text,
	`source_document_source_id` text,
	`source_document_media_type` text,
	`source_document_title` text,
	`source_document_filename` text,
	`tool_tool_call_id` text,
	`tool_name` text,
	`tool_title` text,
	`tool_input` text,
	`tool_output` text,
	`tool_state` text,
	`tool_provider_executed` integer,
	`tool_provider_metadata` text,
	`tool_error_text` text,
	`tool_dynamic` integer,
	`tool_preliminary` integer,
	`tool_approval` text,
	`provider_metadata` text,
	FOREIGN KEY (`message_id`) REFERENCES `messages`(`id`) ON UPDATE no action ON DELETE cascade,
	CONSTRAINT "text_text_required_if_type_is_text" CHECK(CASE WHEN "__new_parts"."type" = 'text' THEN "__new_parts"."text_text" IS NOT NULL ELSE 1 END),
	CONSTRAINT "reasoning_text_required_if_type_is_reasoning" CHECK(CASE WHEN "__new_parts"."type" = 'reasoning' THEN "__new_parts"."reasoning_text" IS NOT NULL ELSE 1 END),
	CONSTRAINT "file_fields_required_if_type_is_file" CHECK(CASE WHEN "__new_parts"."type" = 'file' THEN "__new_parts"."file_media_type" IS NOT NULL AND "__new_parts"."file_url" IS NOT NULL ELSE TRUE END),
	CONSTRAINT "source_url_fields_required_if_type_is_source_url" CHECK(CASE WHEN "__new_parts"."type" = 'source_url' THEN "__new_parts"."source_url_source_id" IS NOT NULL AND "__new_parts"."source_url_url" IS NOT NULL ELSE TRUE END),
	CONSTRAINT "source_document_fields_required_if_type_is_source_document" CHECK(CASE WHEN "__new_parts"."type" = 'source_document' THEN "__new_parts"."source_document_source_id" IS NOT NULL AND "__new_parts"."source_document_media_type" IS NOT NULL AND "__new_parts"."source_document_title" IS NOT NULL ELSE TRUE END),
	CONSTRAINT "tool_fields_required_if_type_is_tool" CHECK(CASE WHEN "__new_parts"."type" = 'tool' THEN "__new_parts"."tool_tool_call_id" IS NOT NULL AND "__new_parts"."tool_name" IS NOT NULL AND "__new_parts"."tool_state" IS NOT NULL ELSE TRUE END)
);
--> statement-breakpoint
INSERT INTO `__new_parts`("id", "message_id", "type", "order", "created_at", "updatedAt", "text_text", "reasoning_text", "file_media_type", "file_filename", "file_url", "source_url_source_id", "source_url_url", "source_url_title", "source_document_source_id", "source_document_media_type", "source_document_title", "source_document_filename", "tool_tool_call_id", "tool_name", "tool_title", "tool_input", "tool_output", "tool_state", "tool_provider_executed", "tool_provider_metadata", "tool_error_text", "tool_dynamic", "tool_preliminary", "tool_approval", "provider_metadata") SELECT "id", "message_id", "type", "order", "created_at", "updatedAt", "text_text", "reasoning_text", "file_media_type", "file_filename", "file_url", "source_url_source_id", "source_url_url", "source_url_title", "source_document_source_id", "source_document_media_type", "source_document_title", "source_document_filename", "tool_tool_call_id", "tool_name", "tool_title", "tool_input", "tool_output", "tool_state", "tool_provider_executed", "tool_provider_metadata", "tool_error_text", "tool_dynamic", "tool_preliminary", "tool_approval", "provider_metadata" FROM `parts`;--> statement-breakpoint
DROP TABLE `parts`;--> statement-breakpoint
ALTER TABLE `__new_parts` RENAME TO `parts`;--> statement-breakpoint
PRAGMA foreign_keys=ON;--> statement-breakpoint
CREATE INDEX `parts_message_id_idx` ON `parts` (`message_id`);--> statement-breakpoint
CREATE INDEX `parts_message_id_order_idx` ON `parts` (`message_id`,`order`);