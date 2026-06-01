PRAGMA foreign_keys=OFF;--> statement-breakpoint
CREATE TABLE `__new_chats` (
	`id` text PRIMARY KEY NOT NULL,
	`title` text NOT NULL,
	`created_at` text DEFAULT CURRENT_TIMESTAMP NOT NULL,
	`updatedAt` text DEFAULT CURRENT_TIMESTAMP NOT NULL
);
--> statement-breakpoint
INSERT INTO `__new_chats`("id", "title", "created_at", "updatedAt") SELECT "id", "title", "created_at", "updatedAt" FROM `chats`;--> statement-breakpoint
DROP TABLE `chats`;--> statement-breakpoint
ALTER TABLE `__new_chats` RENAME TO `chats`;--> statement-breakpoint
PRAGMA foreign_keys=ON;--> statement-breakpoint
CREATE TABLE `__new_messages` (
	`id` text PRIMARY KEY NOT NULL,
	`chat_id` text NOT NULL,
	`role` text NOT NULL,
	`created_at` text DEFAULT CURRENT_TIMESTAMP NOT NULL,
	`updatedAt` text DEFAULT CURRENT_TIMESTAMP NOT NULL,
	FOREIGN KEY (`chat_id`) REFERENCES `chats`(`id`) ON UPDATE no action ON DELETE cascade
);
--> statement-breakpoint
INSERT INTO `__new_messages`("id", "chat_id", "role", "created_at", "updatedAt") SELECT "id", "chat_id", "role", "created_at", "updatedAt" FROM `messages`;--> statement-breakpoint
DROP TABLE `messages`;--> statement-breakpoint
ALTER TABLE `__new_messages` RENAME TO `messages`;--> statement-breakpoint
CREATE INDEX `messages_chat_id_idx` ON `messages` (`chat_id`);--> statement-breakpoint
CREATE INDEX `messages_chat_id_created_at_idx` ON `messages` (`chat_id`,`created_at`);