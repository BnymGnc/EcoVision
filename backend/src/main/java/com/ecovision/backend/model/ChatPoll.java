package com.ecovision.backend.model;

import jakarta.persistence.CollectionTable;
import jakarta.persistence.Column;
import jakarta.persistence.ElementCollection;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.OneToOne;
import jakarta.persistence.OrderColumn;
import jakarta.persistence.Table;
import java.util.ArrayList;
import java.util.List;
import org.hibernate.annotations.OnDelete;
import org.hibernate.annotations.OnDeleteAction;

@Entity
@Table(name = "chat_polls")
public class ChatPoll {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @OneToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "message_id", nullable = false, unique = true)
    @OnDelete(action = OnDeleteAction.CASCADE)
    private ChatMessage message;

    @Column(nullable = false, length = 300)
    private String question;

    @ElementCollection
    @CollectionTable(name = "chat_poll_options", joinColumns = @JoinColumn(name = "poll_id"))
    @OrderColumn(name = "option_index")
    @Column(name = "option_text", nullable = false, length = 160)
    private List<String> options = new ArrayList<>();

    public Long getId() { return id; }
    public ChatMessage getMessage() { return message; }
    public void setMessage(ChatMessage message) { this.message = message; }
    public String getQuestion() { return question; }
    public void setQuestion(String question) { this.question = question; }
    public List<String> getOptions() { return options; }
    public void setOptions(List<String> options) { this.options = new ArrayList<>(options); }
}
