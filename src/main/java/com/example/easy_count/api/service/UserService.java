package com.example.easy_count.api.service;

import com.example.easy_count.api.domain.User;
import com.example.easy_count.api.domain.UserCreateRequest;
import com.example.easy_count.api.domain.UserDto;
import com.example.easy_count.api.repositories.UserRepository;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.NoSuchElementException;
import java.util.stream.Collectors;

@Service
@Transactional
public class UserService {

    private final UserRepository repository;

    public UserService(UserRepository repository) {
        this.repository = repository;
    }

    public UserDto create(UserCreateRequest req) {
        // check duplicates
        repository.findByEmail(req.getEmail()).ifPresent(u -> {
            throw new DataIntegrityViolationException("Email already in use");
        });
        repository.findByUsername(req.getUsername()).ifPresent(u -> {
            throw new DataIntegrityViolationException("Username already in use");
        });

        User user = User.builder()
                .username(req.getUsername())
                .email(req.getEmail())
                .password(req.getPassword())
                .build();

        User saved = repository.save(user);
        return toDto(saved);
    }

    @Transactional(readOnly = true)
    public List<UserDto> listAll() {
        return repository.findAll().stream().map(this::toDto).collect(Collectors.toList());
    }

    @Transactional(readOnly = true)
    public UserDto getById(Long id) {
        return repository.findById(id).map(this::toDto)
                .orElseThrow(() -> new NoSuchElementException("User not found"));
    }

    public UserDto update(Long id, UserCreateRequest req) {
        User user = repository.findById(id).orElseThrow(() -> new NoSuchElementException("User not found"));

        // If email/username changed, check uniqueness
        if (!user.getEmail().equals(req.getEmail())) {
            repository.findByEmail(req.getEmail()).ifPresent(u -> {
                throw new DataIntegrityViolationException("Email already in use");
            });
        }
        if (!user.getUsername().equals(req.getUsername())) {
            repository.findByUsername(req.getUsername()).ifPresent(u -> {
                throw new DataIntegrityViolationException("Username already in use");
            });
        }

        user.setUsername(req.getUsername());
        user.setEmail(req.getEmail());
        user.setPassword(req.getPassword());

        User updated = repository.save(user);
        return toDto(updated);
    }

    public void delete(Long id) {
        if (!repository.existsById(id)) {
            throw new NoSuchElementException("User not found");
        }
        repository.deleteById(id);
    }

    private UserDto toDto(User user) {
        return UserDto.builder()
                .id(user.getId())
                .username(user.getUsername())
                .email(user.getEmail())
                .createdAt(user.getCreatedAt())
                .build();
    }
}

