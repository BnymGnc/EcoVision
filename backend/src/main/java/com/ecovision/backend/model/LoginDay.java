package com.ecovision.backend.model;

import jakarta.persistence.*;
import java.time.LocalDate;

@Entity
@Table(name = "user_login_days", uniqueConstraints = @UniqueConstraint(columnNames = {"user_id", "login_date"}))
public class LoginDay {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY) private Long id;
    @ManyToOne(fetch = FetchType.LAZY, optional = false) @JoinColumn(name = "user_id") private AppUser user;
    @Column(name = "login_date", nullable = false) private LocalDate loginDate;
    protected LoginDay() {}
    public LoginDay(AppUser user, LocalDate date) { this.user = user; this.loginDate = date; }
    public LocalDate getLoginDate() { return loginDate; }
}
