CREATE TABLE `messages` (
	`id` text PRIMARY KEY NOT NULL,
	`chat_id` text NOT NULL,
	`role` text NOT NULL,
	`created_at` text DEFAULT CURRENT_TIMESTAMP,
	`updatedAt` text DEFAULT CURRENT_TIMESTAMP NOT NULL,
	FOREIGN KEY (`chat_id`) REFERENCES `chats`(`id`) ON UPDATE no action ON DELETE cascade
);
--> statement-breakpoint
CREATE INDEX `messages_chat_id_idx` ON `messages` (`chat_id`);--> statement-breakpoint
CREATE INDEX `messages_chat_id_created_at_idx` ON `messages` (`chat_id`,`created_at`);--> statement-breakpoint
CREATE TABLE `parts` (
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
	`tool_state` text,
	`tool_error_text` text,
	`provider_metadata` text,
	FOREIGN KEY (`message_id`) REFERENCES `messages`(`id`) ON UPDATE no action ON DELETE cascade,
	CONSTRAINT "text_text_required_if_type_is_text" CHECK(CASE WHEN "parts"."type" = 'text' THEN "parts"."text_text" IS NOT NULL ELSE 1 END),
	CONSTRAINT "reasoning_text_required_if_type_is_reasoning" CHECK(CASE WHEN "parts"."type" = 'reasoning' THEN "parts"."reasoning_text" IS NOT NULL ELSE 1 END),
	CONSTRAINT "file_fields_required_if_type_is_file" CHECK(CASE WHEN "parts"."type" = 'file' THEN "parts"."file_media_type" IS NOT NULL AND "parts"."file_url" IS NOT NULL ELSE TRUE END),
	CONSTRAINT "source_url_fields_required_if_type_is_source_url" CHECK(CASE WHEN "parts"."type" = 'source_url' THEN "parts"."source_url_source_id" IS NOT NULL AND "parts"."source_url_url" IS NOT NULL ELSE TRUE END),
	CONSTRAINT "source_document_fields_required_if_type_is_source_document" CHECK(CASE WHEN "parts"."type" = 'source_document' THEN "parts"."source_document_source_id" IS NOT NULL AND "parts"."source_document_media_type" IS NOT NULL AND "parts"."source_document_title" IS NOT NULL ELSE TRUE END)
);
--> statement-breakpoint
CREATE INDEX `parts_message_id_idx` ON `parts` (`message_id`);--> statement-breakpoint
CREATE INDEX `parts_message_id_order_idx` ON `parts` (`message_id`,`order`);