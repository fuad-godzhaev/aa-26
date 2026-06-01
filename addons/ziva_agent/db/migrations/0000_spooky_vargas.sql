CREATE TABLE `chats` (
	`id` text PRIMARY KEY NOT NULL,
	`title` text NOT NULL,
	`created_at` text DEFAULT CURRENT_TIMESTAMP,
	`updatedAt` text DEFAULT CURRENT_TIMESTAMP NOT NULL
);
