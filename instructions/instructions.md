# **Product Requirements Document (PRD): iOS Social Media Application**

## **1. Project Overview**
### **Objective**
The goal of this application is to create a social media platform where users can share videos and pictures, interact with content, follow other users, and categorize their posts based on topics of interest. 

### **Key Features**
- Users can take/upload videos and pictures.
- Users have follower and following lists.
- Users can view a timeline showing posts from followed users and relevant topics.
- Posts can be categorized.
- Posts can include external links (YouTube, articles, academic papers).
- Users can like, comment, and share posts.
- Users receive notifications for interactions (likes, comments, follows, mentions, etc.).
- Posts can have collaborators.

## **2. Features & Requirements**

### **1. User Profiles**
#### **Requirements**
- Users can sign up and create profiles.
- Users can edit their profile (username, bio, profile picture).
- Users can follow/unfollow other users.

#### **API Endpoints**
- `POST /user/signup`
- `GET /user/{userId}`
- `PUT /user/{userId}/update`
- `POST /user/{userId}/follow`
- `DELETE /user/{userId}/unfollow`

#### **Data Model**
```json
{
  "userId": "string",
  "username": "string",
  "email": "string",
  "profilePicture": "url",
  "bio": "string",
  "followers": ["userId"],
  "following": ["userId"],
  "createdAt": "timestamp",
  "updatedAt": "timestamp"
}
```

---

### **2. Posts**
#### **Requirements**
- Users can upload videos and pictures.
- Users can categorize posts.
- Posts can include external links.
- Posts can have collaborators.

#### **API Endpoints**
- `POST /post/create`
- `GET /post/{postId}`
- `DELETE /post/{postId}`

#### **Data Model**
```json
{
  "postId": "string",
  "userId": "string",
  "mediaUrl": "url",
  "caption": "string",
  "category": "string",
  "link": "url",
  "collaborators": ["userId"],
  "likesCount": 0,
  "commentsCount": 0,
  "sharesCount": 0,
  "createdAt": "timestamp",
  "updatedAt": "timestamp"
}
```

---

### **3. Timeline & Categories**
#### **Requirements**
- Users have a timeline of followed users’ posts.
- Users can filter timelines by categories.

#### **API Endpoints**
- `GET /timeline/{userId}`
- `GET /timeline/{userId}/category/{categoryName}`

---

### **4. Likes, Comments, and Shares**
#### **Requirements**
- Users can like/unlike posts.
- Users can comment on posts.
- Users can share posts internally or externally.

#### **API Endpoints**
- `POST /post/{postId}/like`
- `DELETE /post/{postId}/like`
- `POST /post/{postId}/comment`
- `POST /post/{postId}/share`

#### **Data Models**
**Likes**
```json
{
  "likeId": "string",
  "postId": "string",
  "userId": "string",
  "createdAt": "timestamp"
}
```

**Comments**
```json
{
  "commentId": "string",
  "postId": "string",
  "userId": "string",
  "text": "string",
  "createdAt": "timestamp"
}
```

**Shares**
```json
{
  "shareId": "string",
  "postId": "string",
  "userId": "string",
  "platform": "string",
  "createdAt": "timestamp"
}
```

---

### **5. Notifications**
#### **Requirements**
- Users receive notifications for likes, comments, shares, follows, and mentions.
- Users can mark notifications as read.

#### **API Endpoints**
- `GET /notifications/{userId}`
- `PUT /notifications/{notificationId}/mark-as-read`

#### **Data Model**
```json
{
  "notificationId": "string",
  "userId": "string",
  "type": "like | comment | share | follow | mention | collaboration",
  "fromUserId": "string",
  "postId": "string | null",
  "message": "string",
  "isRead": false,
  "createdAt": "timestamp"
}
```

---

## **3. Tech Stack & Dependencies**
- **Frontend**: Swift (iOS)
- **Backend, Database, Storage, Authentication**: Appwrite

---

## **4. API Contracts**
Below is an example of an API contract for creating a post.

### **Endpoint: `POST /post/create`**
#### **Request**
```json
{
  "userId": "abc123",
  "mediaUrl": "https://example.com/media.mp4",
  "caption": "Check this out!",
  "category": "Technology",
  "link": "https://example.com/article",
  "collaborators": ["user456"]
}
```

#### **Response**
```json
{
  "postId": "xyz789",
  "status": "success"
}
```

---

