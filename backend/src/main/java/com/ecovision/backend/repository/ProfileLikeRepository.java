package com.ecovision.backend.repository;

import com.ecovision.backend.model.ProfileLike;
import org.springframework.data.jpa.repository.JpaRepository;

public interface ProfileLikeRepository extends JpaRepository<ProfileLike, Long> {
    boolean existsByLikerIdAndLikedUserId(Long likerId, Long likedUserId);
    long countByLikedUserId(Long likedUserId);
    void deleteByLikerIdAndLikedUserId(Long likerId, Long likedUserId);
}
