package com.ecovision.backend.repository;

import com.ecovision.backend.model.AppUser;
import jakarta.persistence.LockModeType;
import java.util.Optional;
import java.util.List;
import java.time.LocalDate;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.data.domain.Pageable;

public interface AppUserRepository extends JpaRepository<AppUser, Long> {
    @EntityGraph(attributePaths = "ownedMarketItems")
    Optional<AppUser> findByEmail(String email);

    @Override
    @EntityGraph(attributePaths = "ownedMarketItems")
    List<AppUser> findAll();

    boolean existsByEmail(String email);

    boolean existsByPublicUsername(String publicUsername);

    Optional<AppUser> findByPublicUsername(String publicUsername);

    @Query("""
            select user from AppUser user
            where user.dateOfBirth <= :adultCutoff
              and (
                lower(user.publicUsername) like lower(concat('%', :query, '%'))
                or lower(user.name) like lower(concat('%', :query, '%'))
                or lower(user.surname) like lower(concat('%', :query, '%'))
                or lower(concat(concat(user.name, ' '), user.surname))
                    like lower(concat('%', :query, '%'))
              )
            order by user.totalPoints desc, user.name asc
            """)
    List<AppUser> searchAdultUsers(
            @Param("query") String query,
            @Param("adultCutoff") LocalDate adultCutoff,
            Pageable pageable
    );

    List<AppUser> findByCityIgnoreCaseOrderByTotalPointsDescNameAsc(String city);

    List<AppUser> findByCityIgnoreCase(String city);

    List<AppUser> findByLastLoginDateGreaterThanEqual(LocalDate activeSince);

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select user from AppUser user where user.id = :id")
    Optional<AppUser> findByIdForUpdate(@Param("id") Long id);
}
