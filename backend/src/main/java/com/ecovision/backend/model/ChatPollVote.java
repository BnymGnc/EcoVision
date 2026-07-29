package com.ecovision.backend.model;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import jakarta.persistence.UniqueConstraint;
import org.hibernate.annotations.OnDelete;
import org.hibernate.annotations.OnDeleteAction;

@Entity
@Table(
        name = "chat_poll_votes",
        uniqueConstraints = @UniqueConstraint(columnNames = {"poll_id", "user_id"})
)
public class ChatPollVote {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "poll_id", nullable = false)
    @OnDelete(action = OnDeleteAction.CASCADE)
    private ChatPoll poll;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false)
    private AppUser user;

    @Column(nullable = false)
    private int optionIndex;

    public Long getId() { return id; }
    public ChatPoll getPoll() { return poll; }
    public void setPoll(ChatPoll poll) { this.poll = poll; }
    public AppUser getUser() { return user; }
    public void setUser(AppUser user) { this.user = user; }
    public int getOptionIndex() { return optionIndex; }
    public void setOptionIndex(int optionIndex) { this.optionIndex = optionIndex; }
}
