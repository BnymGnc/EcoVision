package com.ecovision.backend.model;

import com.fasterxml.jackson.annotation.JsonIgnore;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.PrePersist;
import jakarta.persistence.Table;
import java.time.Instant;

@Entity
@Table(name = "chat_messages")
public class ChatMessage {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "event_id")
    private Event event;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "group_id")
    private CommunityGroup group;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "group_event_id")
    private GroupEvent groupEvent;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "sender_id", nullable = false)
    private AppUser sender;

    @Column(nullable = false, length = 2000)
    private String message;

    private String imageUrl;

    private String fileUrl;

    private String fileName;

    private String contentType;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "reply_to_message_id")
    private ChatMessage replyTo;

    @Column(nullable = false, columnDefinition = "boolean default false")
    private boolean deleted;

    private Instant deletedAt;

    @Enumerated(EnumType.STRING)
    @Column(
            name = "message_type",
            nullable = false,
            columnDefinition = "varchar(30) default 'USER'"
    )
    private ChatMessageType messageType = ChatMessageType.USER;

    @Column(nullable = false)
    private Instant timestamp;

    @PrePersist
    void prePersist() {
        if (timestamp == null) {
            timestamp = Instant.now();
        }
        if (messageType == null) {
            messageType = ChatMessageType.USER;
        }
    }

    public Long getId() {
        return id;
    }

    @JsonIgnore
    public Event getEvent() {
        return event;
    }

    public void setEvent(Event event) {
        this.event = event;
    }

    @JsonIgnore
    public CommunityGroup getGroup() {
        return group;
    }

    public void setGroup(CommunityGroup group) {
        this.group = group;
    }

    @JsonIgnore
    public GroupEvent getGroupEvent() {
        return groupEvent;
    }

    public void setGroupEvent(GroupEvent groupEvent) {
        this.groupEvent = groupEvent;
    }

    @JsonIgnore
    public AppUser getSender() {
        return sender;
    }

    public void setSender(AppUser sender) {
        this.sender = sender;
    }

    public String getMessage() {
        return message;
    }

    public void setMessage(String message) {
        this.message = message;
    }

    public String getImageUrl() { return imageUrl; }
    public void setImageUrl(String imageUrl) { this.imageUrl = imageUrl; }

    public String getFileUrl() { return fileUrl; }
    public void setFileUrl(String fileUrl) { this.fileUrl = fileUrl; }
    public String getFileName() { return fileName; }
    public void setFileName(String fileName) { this.fileName = fileName; }
    public String getContentType() { return contentType; }
    public void setContentType(String contentType) { this.contentType = contentType; }
    public ChatMessage getReplyTo() { return replyTo; }
    public void setReplyTo(ChatMessage replyTo) { this.replyTo = replyTo; }
    public boolean isDeleted() { return deleted; }
    public void setDeleted(boolean deleted) { this.deleted = deleted; }
    public Instant getDeletedAt() { return deletedAt; }
    public void setDeletedAt(Instant deletedAt) { this.deletedAt = deletedAt; }

    public ChatMessageType getMessageType() {
        return messageType == null ? ChatMessageType.USER : messageType;
    }

    public void setMessageType(ChatMessageType messageType) {
        this.messageType = messageType;
    }

    public Instant getTimestamp() {
        return timestamp;
    }
}
