package com.ecovision.backend.repository;

import com.ecovision.backend.model.Friendship;
import com.ecovision.backend.model.FriendshipStatus;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface FriendshipRepository extends JpaRepository<Friendship, Long> {
    @EntityGraph(attributePaths = {"requester", "addressee"})
    @Query("""
            select f from Friendship f
            where (f.requester.id = :first and f.addressee.id = :second)
               or (f.requester.id = :second and f.addressee.id = :first)
            """)
    Optional<Friendship> findBetween(@Param("first") Long first, @Param("second") Long second);

    @EntityGraph(attributePaths = {"requester", "addressee"})
    @Query("""
            select f from Friendship f
            where f.status = :status
              and (f.requester.id = :userId or f.addressee.id = :userId)
            order by f.createdAt desc
            """)
    List<Friendship> findForUser(
            @Param("userId") Long userId,
            @Param("status") FriendshipStatus status
    );

    @EntityGraph(attributePaths = {"requester", "addressee"})
    List<Friendship> findByAddresseeIdAndStatusOrderByCreatedAtDesc(
            Long addresseeId,
            FriendshipStatus status
    );
}
