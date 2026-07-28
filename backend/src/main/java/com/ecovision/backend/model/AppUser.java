package com.ecovision.backend.model;

import jakarta.persistence.Column;
import jakarta.persistence.CollectionTable;
import jakarta.persistence.ElementCollection;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.FetchType;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.PrePersist;
import jakarta.persistence.Table;
import java.time.Instant;
import java.time.LocalDate;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.userdetails.UserDetails;

import java.util.Collection;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Set;

@Entity
@Table(name = "users")
public class AppUser implements UserDetails {
    public static final String DEFAULT_CITY = "Şanlıurfa";

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private String name;

    @Column(nullable = false)
    private String surname;

    @Column(nullable = false, unique = true)
    private String email;

    @Column(name = "username", unique = true, length = 30)
    private String publicUsername;

    @Column(nullable = false)
    private String password;

    private Integer age;

    private LocalDate dateOfBirth;

    private String profilePictureUrl;

    private String city = DEFAULT_CITY;

    private String district;

    private String neighborhood;

    private Integer equippedAvatarLevel = 1;

    private Instant communityReadAt;

    private LocalDate lastLoginDate;

    private Integer loginStreakCount = 0;

    private LocalDate lastScanDate;

    private Integer streakCount = 0;

    private Integer streakFreezeCount = 0;

    @Column(nullable = false, columnDefinition = "boolean default false")
    private boolean banned = false;

    private Instant suspendedUntil;

    @Column(nullable = false, columnDefinition = "integer default 0")
    private Integer failedLoginAttempts = 0;

    private Instant lockoutUntil;

    private Instant termsAcceptedAt;

    private Instant privacyAcceptedAt;

    @Column(nullable = false)
    private Integer totalPoints = 0;

    private Integer lifetimePoints = 0;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private Role role = Role.USER;

    @Enumerated(EnumType.STRING)
    @Column(
            name = "profile_visibility",
            nullable = false,
            columnDefinition = "varchar(20) default 'PUBLIC'"
    )
    private ProfileVisibility profileVisibility = ProfileVisibility.PUBLIC;

    @ElementCollection(fetch = FetchType.LAZY)
    @CollectionTable(
            name = "user_market_items",
            joinColumns = @JoinColumn(name = "user_id")
    )
    @Column(name = "item_id", nullable = false)
    private Set<String> ownedMarketItems = new LinkedHashSet<>();

    @Column(nullable = false, updatable = false)
    private Instant createdAt;

    @PrePersist
    void prePersist() {
        createdAt = Instant.now();
        if (profileVisibility == null) {
            profileVisibility = ProfileVisibility.PUBLIC;
        }
    }

    public Long getId() {
        return id;
    }

    public void setId(Long id) {
        this.id = id;
    }

    public String getName() {
        return name;
    }

    public void setName(String name) {
        this.name = name;
    }

    public String getSurname() {
        return surname;
    }

    public void setSurname(String surname) {
        this.surname = surname;
    }

    public String getEmail() {
        return email;
    }

    public void setEmail(String email) {
        this.email = email;
    }

    public String getPublicUsername() {
        return publicUsername;
    }

    public void setPublicUsername(String publicUsername) {
        this.publicUsername = publicUsername;
    }

    @Override
    public String getPassword() {
        return password;
    }

    public void setPassword(String password) {
        this.password = password;
    }

    public Integer getAge() {
        if (dateOfBirth != null) {
            return java.time.Period.between(dateOfBirth, LocalDate.now()).getYears();
        }
        return age;
    }

    public void setAge(Integer age) {
        this.age = age;
    }

    public LocalDate getDateOfBirth() {
        return dateOfBirth;
    }

    public void setDateOfBirth(LocalDate dateOfBirth) {
        this.dateOfBirth = dateOfBirth;
        this.age = dateOfBirth == null
                ? age
                : java.time.Period.between(dateOfBirth, LocalDate.now()).getYears();
    }

    public String getProfilePictureUrl() {
        return profilePictureUrl;
    }

    public void setProfilePictureUrl(String profilePictureUrl) {
        this.profilePictureUrl = profilePictureUrl;
    }

    public String getCity() {
        return city;
    }

    public void setCity(String city) {
        this.city = city;
    }

    public String getDistrict() {
        return district;
    }

    public void setDistrict(String district) {
        this.district = district;
    }

    public String getNeighborhood() {
        return neighborhood;
    }

    public void setNeighborhood(String neighborhood) {
        this.neighborhood = neighborhood;
    }

    public Integer getEquippedAvatarLevel() {
        return equippedAvatarLevel == null ? 1 : equippedAvatarLevel;
    }

    public void setEquippedAvatarLevel(Integer equippedAvatarLevel) {
        this.equippedAvatarLevel = equippedAvatarLevel;
    }

    public Instant getCommunityReadAt() {
        return communityReadAt;
    }

    public void setCommunityReadAt(Instant communityReadAt) {
        this.communityReadAt = communityReadAt;
    }

    public LocalDate getLastLoginDate() { return lastLoginDate; }
    public void setLastLoginDate(LocalDate lastLoginDate) { this.lastLoginDate = lastLoginDate; }
    public Integer getLoginStreakCount() {
        return loginStreakCount == null ? 0 : loginStreakCount;
    }
    public void setLoginStreakCount(Integer loginStreakCount) {
        this.loginStreakCount = loginStreakCount;
    }
    public LocalDate getLastScanDate() { return lastScanDate; }
    public void setLastScanDate(LocalDate lastScanDate) { this.lastScanDate = lastScanDate; }
    public Integer getStreakCount() { return streakCount == null ? 0 : streakCount; }
    public void setStreakCount(Integer streakCount) { this.streakCount = streakCount; }
    public Integer getStreakFreezeCount() { return streakFreezeCount == null ? 0 : streakFreezeCount; }
    public void setStreakFreezeCount(Integer streakFreezeCount) { this.streakFreezeCount = streakFreezeCount; }
    public boolean isAdult() {
        Integer calculatedAge = getAge();
        return calculatedAge != null && calculatedAge >= 18;
    }
    public boolean isBanned() { return banned; }
    public void setBanned(boolean banned) { this.banned = banned; }
    public Instant getSuspendedUntil() { return suspendedUntil; }
    public void setSuspendedUntil(Instant suspendedUntil) { this.suspendedUntil = suspendedUntil; }
    public boolean isSuspended() { return suspendedUntil != null && suspendedUntil.isAfter(Instant.now()); }
    public Integer getFailedLoginAttempts() { return failedLoginAttempts == null ? 0 : failedLoginAttempts; }
    public void setFailedLoginAttempts(Integer failedLoginAttempts) { this.failedLoginAttempts = failedLoginAttempts; }
    public Instant getLockoutUntil() { return lockoutUntil; }
    public void setLockoutUntil(Instant lockoutUntil) { this.lockoutUntil = lockoutUntil; }
    public Instant getTermsAcceptedAt() { return termsAcceptedAt; }
    public void setTermsAcceptedAt(Instant termsAcceptedAt) { this.termsAcceptedAt = termsAcceptedAt; }
    public Instant getPrivacyAcceptedAt() { return privacyAcceptedAt; }
    public void setPrivacyAcceptedAt(Instant privacyAcceptedAt) { this.privacyAcceptedAt = privacyAcceptedAt; }

    public Integer getTotalPoints() {
        return totalPoints;
    }

    public void setTotalPoints(Integer totalPoints) {
        this.totalPoints = totalPoints;
    }

    public Integer getLifetimePoints() {
        return lifetimePoints == null ? totalPoints : lifetimePoints;
    }

    public void setLifetimePoints(Integer lifetimePoints) {
        this.lifetimePoints = lifetimePoints;
    }

    public Role getRole() {
        return role;
    }

    public void setRole(Role role) {
        this.role = role;
    }

    public ProfileVisibility getProfileVisibility() {
        return profileVisibility == null ? ProfileVisibility.PUBLIC : profileVisibility;
    }

    public void setProfileVisibility(ProfileVisibility profileVisibility) {
        this.profileVisibility = profileVisibility;
    }

    public Set<String> getOwnedMarketItems() {
        return ownedMarketItems;
    }

    public void setOwnedMarketItems(Set<String> ownedMarketItems) {
        this.ownedMarketItems = ownedMarketItems;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }

    @Override
    public Collection<? extends GrantedAuthority> getAuthorities() {
        return List.of(new SimpleGrantedAuthority("ROLE_" + role.name()));
    }

    @Override
    public String getUsername() {
        return email;
    }

    @Override
    public boolean isAccountNonExpired() {
        return true;
    }

    @Override
    public boolean isAccountNonLocked() {
        return !banned
                && !isSuspended()
                && (lockoutUntil == null || !lockoutUntil.isAfter(Instant.now()));
    }

    @Override
    public boolean isCredentialsNonExpired() {
        return true;
    }

    @Override
    public boolean isEnabled() {
        return true;
    }
}
