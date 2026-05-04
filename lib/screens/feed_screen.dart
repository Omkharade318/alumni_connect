import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';
import '../services/firestore_service.dart';
import '../services/storage_service.dart';
import 'package:share_plus/share_plus.dart';
import '../models/post_model.dart';
import '../models/comment_model.dart';
import '../models/user_model.dart';
import '../widgets/profile_avatar.dart';
import '../widgets/full_screen_image_viewer.dart';
import 'alumini_details_screen.dart';

class FeedScreen extends StatelessWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50, // Modern off-white background
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreatePostDialog(context),
        backgroundColor: AppTheme.primaryRed,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.edit_square, color: Colors.white),
      ),
      body: StreamBuilder<List<PostModel>>(
        stream: FirestoreService().getPostsStream(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final posts = snapshot.data!;
          if (posts.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(color: Colors.grey.shade100, shape: BoxShape.circle),
                    child: Icon(Icons.post_add_rounded, size: 64, color: Colors.grey.shade400),
                  ),
                  const SizedBox(height: 24),
                  const Text('No posts yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                  const SizedBox(height: 8),
                  Text('Be the first to share an update!', style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryRed,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    onPressed: () => _showCreatePostDialog(context),
                    child: const Text('Create Post', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
          }
          return MediaQuery.removePadding(
            context: context,
            removeTop: true,
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 80), // Extra bottom padding for FAB
              itemCount: posts.length,
              itemBuilder: (_, i) => _PostCard(post: posts[i]),
            ),
          );
        },
      ),
    );
  }

  void _showCreatePostDialog(BuildContext context) {
    final contentController = TextEditingController();
    final locationController = TextEditingController(); // Added to match the UI
    File? selectedImage; // Adapted to a single image to match the prominent UI style
    bool isPosting = false;

    final user = context.read<AuthProvider>().currentUser;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final bool canPost = !isPosting &&
              (contentController.text.trim().isNotEmpty || selectedImage != null);

          // A soft color for the borders to match the image's aesthetic
          final Color borderColor = Colors.grey.shade400;

          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Soft Drag Handle matching the image
                  Center(
                    child: Container(
                      width: 32,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 24),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryRed.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // Prominent Hero Image Picker / Preview
                  GestureDetector(
                    onTap: isPosting
                        ? null
                        : () async {
                      final picker = ImagePicker();
                      final image = await picker.pickImage(source: ImageSource.gallery);
                      if (image != null) {
                        setModalState(() {
                          selectedImage = File(image.path);
                        });
                      }
                    },
                    child: Container(
                      height: 220,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(16),
                        border: selectedImage == null ? Border.all(color: borderColor) : null,
                      ),
                      child: selectedImage != null
                          ? Stack(
                        fit: StackFit.expand,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.file(
                              selectedImage!,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 12,
                            right: 12,
                            child: GestureDetector(
                              onTap: () => setModalState(() => selectedImage = null),
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.6),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
                              ),
                            ),
                          ),
                        ],
                      )
                          : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate_outlined, size: 48, color: Colors.grey.shade400),
                          const SizedBox(height: 8),
                          Text('Tap to add photo', style: TextStyle(color: Colors.grey.shade500)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Caption Field
                  TextField(
                    controller: contentController,
                    maxLines: 4,
                    minLines: 3,
                    textInputAction: TextInputAction.newline,
                    onChanged: (text) => setModalState(() {}),
                    style: const TextStyle(fontSize: 15, color: Colors.black87),
                    decoration: InputDecoration(
                      hintText: 'Write a caption...',
                      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 15),
                      contentPadding: const EdgeInsets.all(16),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: borderColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppTheme.primaryRed.withOpacity(0.5), width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Location Field
                  TextField(
                    controller: locationController,
                    style: const TextStyle(fontSize: 15, color: Colors.black87),
                    decoration: InputDecoration(
                      hintText: 'Add location (optional)',
                      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 15),
                      prefixIcon: Icon(Icons.location_on_outlined, color: AppTheme.primaryRed.withOpacity(0.5), size: 22),
                      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: borderColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppTheme.primaryRed.withOpacity(0.5), width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Bottom Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 50,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.primaryRed.withOpacity(0.7),
                              side: BorderSide(color: AppTheme.primaryRed.withOpacity(0.4)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                            ),
                            onPressed: isPosting ? null : () => Navigator.pop(ctx),
                            child: const Text('Cancel', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: SizedBox(
                          height: 50,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryRed.withOpacity(canPost ? 0.9 : 0.4),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                            ),
                            onPressed: !canPost
                                ? null
                                : () async {
                              if (user == null) return;
                              setModalState(() => isPosting = true);
                              try {
                                List<String> imageUrls = [];
                                if (selectedImage != null) {
                                  final url = await StorageService().uploadPostImage(user.uid, selectedImage!);
                                  imageUrls.add(url);
                                }

                                final post = PostModel(
                                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                                  userId: user.uid,
                                  userName: user.name,
                                  userImage: user.profileImage,
                                  userJobTitle: user.jobTitle,
                                  userDegree: user.degree,
                                  userBranch: user.branch,
                                  userBatch: user.batch,
                                  content: contentController.text.trim(),
                                  imageUrls: imageUrls,
                                  // Note: To use `locationController.text`, add a location field to your PostModel
                                  createdAt: DateTime.now(),
                                );

                                await FirestoreService().createPost(post);
                                if (context.mounted) Navigator.pop(ctx);
                              } catch (e) {
                                if (context.mounted) {
                                  setModalState(() => isPosting = false);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Failed to post: $e'),
                                      behavior: SnackBarBehavior.floating,
                                      backgroundColor: Colors.red.shade600,
                                    ),
                                  );
                                }
                              }
                            },
                            child: isPosting
                                ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)
                            )
                                : const Text('Post', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  final PostModel post;

  const _PostCard({required this.post});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final isLiked = user != null && post.isLikedBy(user.uid);
    final firestore = FirestoreService();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Author Header
          GestureDetector(
            onTap: () async {
              final targetUser = await firestore.getUser(post.userId);
              if (targetUser != null && context.mounted) {
                Navigator.push(context, MaterialPageRoute(builder: (_) => AlumniDetailScreen(alumni: targetUser)));
              }
            },
            child: StreamBuilder<UserModel?>(
              stream: firestore.getUserStream(post.userId),
              builder: (context, userSnapshot) {
                final liveUser = userSnapshot.data;
                final displayName = liveUser?.name ?? post.userName;
                final displayImage = liveUser?.profileImage ?? post.userImage;

                final String subtitleDetails = [
                  liveUser?.jobTitle ?? post.userJobTitle,
                  liveUser?.degree ?? post.userDegree ?? "Alumni",
                  liveUser?.branch ?? post.userBranch,
                  liveUser?.batch ?? post.userBatch,
                ].where((e) => e != null && e.isNotEmpty).join(' • ');

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ProfileAvatar(imageUrl: displayImage, name: displayName, size: 48),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  displayName,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                _formatDate(post.createdAt),
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitleDetails,
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 16),

          // Post Content
          Text(
            post.content,
            style: const TextStyle(fontSize: 15, height: 1.5, color: Colors.black87),
          ),

          // Image Attachments
          if (post.imageUrls != null && post.imageUrls!.isNotEmpty) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => FullScreenImageViewer(imageUrl: post.imageUrls![0], tag: 'post_${post.id}'),
                  ),
                );
              },
              child: Hero(
                tag: 'post_${post.id}',
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    post.imageUrls![0],
                    width: double.infinity,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        height: 200,
                        color: Colors.grey.shade100,
                        child: const Center(child: CircularProgressIndicator()),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),

          // Engagement Stats
          if (post.likes.isNotEmpty || post.commentCount > 0) ...[
            Row(
              children: [
                if (post.likes.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: AppTheme.primaryRed, shape: BoxShape.circle),
                    child: const Icon(Icons.thumb_up_rounded, size: 10, color: Colors.white),
                  ),
                  const SizedBox(width: 6),
                  Text('${post.likes.length}', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                ],
                const Spacer(),
                if (post.commentCount > 0)
                  Text('${post.commentCount} comments', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
              ],
            ),
            const SizedBox(height: 12),
          ],

          const Divider(height: 1, color: Colors.black12),
          const SizedBox(height: 4),

          // Modern Action Bar (Horizontal layout)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _ActionButton(
                icon: isLiked ? Icons.thumb_up_rounded : Icons.thumb_up_outlined,
                label: 'Like',
                color: isLiked ? AppTheme.primaryRed : Colors.grey.shade700,
                onPressed: user == null ? null : () => firestore.likePost(post.id, user.uid, isLiked),
              ),
              _ActionButton(
                icon: Icons.chat_bubble_outline_rounded,
                label: 'Comment',
                color: Colors.grey.shade700,
                onPressed: () => _showComments(context, post),
              ),
              _ActionButton(
                icon: Icons.share_rounded,
                label: 'Share',
                color: Colors.grey.shade700,
                onPressed: () {
                  Share.share(
                    '${post.userName} posted on Alumni Connect: \n\n${post.content}',
                    subject: 'Check out this post from ${post.userName}',
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showComments(BuildContext context, PostModel post) {
    final commentController = TextEditingController();
    final user = context.read<AuthProvider>().currentUser;
    final firestore = FirestoreService();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.88,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Stack(
          children: [
            // 1. Scrollable Comments List (Placed at the bottom of the stack)
            Positioned.fill(
              top: 70, // Pushed down to account for the fixed header
              bottom: 0,
              child: StreamBuilder<List<CommentModel>>(
                stream: firestore.getCommentsStream(post.id),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final comments = snapshot.data!;

                  if (comments.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(color: Colors.grey.shade50, shape: BoxShape.circle),
                            child: Icon(Icons.forum_outlined, size: 56, color: Colors.grey.shade300),
                          ),
                          const SizedBox(height: 16),
                          Text('No comments yet', style: TextStyle(color: Colors.grey.shade800, fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          Text('Be the first to share your thoughts!', style: TextStyle(color: Colors.grey.shade500, fontSize: 15)),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    // Extra bottom padding so the last comment isn't hidden behind the floating input
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                    itemCount: comments.length,
                    itemBuilder: (_, i) {
                      final comment = comments[i];
                      final isCommentAuthor = user?.uid == comment.userId;
                      final isPostAuthor = user?.uid == post.userId;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 24),
                        child: StreamBuilder<UserModel?>(
                          stream: firestore.getUserStream(comment.userId),
                          builder: (context, userSnapshot) {
                            final liveUser = userSnapshot.data;
                            final displayName = liveUser?.name ?? comment.userName;
                            final displayImage = liveUser?.profileImage ?? comment.userImage;

                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Avatar
                                GestureDetector(
                                  onTap: () async {
                                    final targetUser = await firestore.getUser(comment.userId);
                                    if (targetUser != null && context.mounted) {
                                      Navigator.push(context, MaterialPageRoute(builder: (_) => AlumniDetailScreen(alumni: targetUser)));
                                    }
                                  },
                                  child: ProfileAvatar(imageUrl: displayImage, name: displayName, size: 42),
                                ),
                                const SizedBox(width: 12),

                                // Comment Body
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Distinct Bubbles: Tinted for the current user, grey for others
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                        decoration: BoxDecoration(
                                          color: isCommentAuthor ? AppTheme.primaryRed.withOpacity(0.06) : Colors.grey.shade100,
                                          borderRadius: const BorderRadius.only(
                                            topRight: Radius.circular(20),
                                            bottomLeft: Radius.circular(20),
                                            bottomRight: Radius.circular(20),
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    displayName,
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 14,
                                                      color: isCommentAuthor ? AppTheme.primaryRed : Colors.black87,
                                                    ),
                                                  ),
                                                ),
                                                if (isCommentAuthor || isPostAuthor)
                                                  _buildCommentOptions(context, post, comment, isCommentAuthor),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              comment.content,
                                              style: const TextStyle(fontSize: 15, color: Colors.black87, height: 1.4),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Padding(
                                        padding: const EdgeInsets.only(left: 8),
                                        child: Text(
                                          _formatDate(comment.createdAt),
                                          style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      );
                    },
                  );
                },
              ),
            ),

            // 2. Glassmorphic Sticky Header
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    color: Colors.white.withOpacity(0.85),
                    child: Column(
                      children: [
                        // Drag Handle
                        Center(
                          child: Container(
                            width: 40,
                            height: 5,
                            margin: const EdgeInsets.only(top: 12, bottom: 8),
                            decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(4)),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 16, 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Comments (${post.commentCount})',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                              ),
                              IconButton(
                                icon: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(color: Colors.grey.shade100, shape: BoxShape.circle),
                                  child: Icon(Icons.close_rounded, size: 18, color: Colors.grey.shade700),
                                ),
                                onPressed: () => Navigator.pop(ctx),
                                constraints: const BoxConstraints(),
                                padding: EdgeInsets.zero,
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1, color: Colors.black12),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // 3. Floating Pill Input Area
            Positioned(
              bottom: MediaQuery.of(ctx).viewInsets.bottom > 0 ? MediaQuery.of(ctx).viewInsets.bottom + 12 : 24,
              left: 16,
              right: 16,
              child: StatefulBuilder(
                  builder: (context, setInputState) {
                    final hasText = commentController.text.trim().isNotEmpty;

                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.1), offset: const Offset(0, 4), blurRadius: 16),
                        ],
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const SizedBox(width: 20),
                          Expanded(
                            child: TextField(
                              controller: commentController,
                              maxLines: 4,
                              minLines: 1,
                              textInputAction: TextInputAction.newline,
                              onChanged: (val) => setInputState(() {}), // Trigger rebuild to light up send button
                              style: const TextStyle(fontSize: 15, height: 1.4),
                              decoration: const InputDecoration(
                                hintText: 'Add a comment...',
                                hintStyle: TextStyle(color: Colors.grey),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(vertical: 14),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(right: 6, bottom: 6),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              decoration: BoxDecoration(
                                color: hasText ? AppTheme.primaryRed : Colors.grey.shade100,
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                icon: Icon(Icons.send_rounded, color: hasText ? Colors.white : Colors.grey.shade400, size: 20),
                                onPressed: hasText
                                    ? () async {
                                  if (user == null) return;

                                  final content = commentController.text.trim();
                                  commentController.clear();
                                  FocusScope.of(context).unfocus();
                                  setInputState(() {}); // Reset button state

                                  final comment = CommentModel(
                                    id: '',
                                    userId: user.uid,
                                    userName: user.name,
                                    userImage: user.profileImage,
                                    content: content,
                                    createdAt: DateTime.now(),
                                  );

                                  await firestore.createComment(post.id, comment);
                                }
                                    : null,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime d) {
    final now = DateTime.now();
    final diff = now.difference(d);
    if (diff.inDays > 7) {
      return '${d.day}/${d.month}/${d.year}';
    }
    if (diff.inDays > 0) return '${diff.inDays}d';
    if (diff.inHours > 0) return '${diff.inHours}h';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m';
    return 'now';
  }

  Widget _buildCommentOptions(BuildContext context, PostModel post, CommentModel comment, bool canEdit) {
    return PopupMenuButton<String>(
      padding: EdgeInsets.zero,
      menuPadding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      icon: Icon(Icons.more_horiz_rounded, size: 18, color: Colors.grey.shade500),
      onSelected: (value) {
        if (value == 'edit') {
          _showEditCommentDialog(context, post, comment);
        } else if (value == 'delete') {
          _showDeleteCommentDialog(context, post, comment);
        }
      },
      itemBuilder: (ctx) => [
        if (canEdit)
          PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit_rounded, size: 18, color: Colors.grey.shade700),
                  const SizedBox(width: 8),
                  const Text('Edit', style: TextStyle(fontWeight: FontWeight.w500)),
                ],
              )
          ),
        PopupMenuItem(
            value: 'delete',
            child: Row(
              children: [
                Icon(Icons.delete_rounded, size: 18, color: Colors.red.shade600),
                const SizedBox(width: 8),
                Text('Delete', style: TextStyle(color: Colors.red.shade600, fontWeight: FontWeight.w500)),
              ],
            )
        ),
      ],
    );
  }

  void _showEditCommentDialog(BuildContext context, PostModel post, CommentModel comment) {
    final controller = TextEditingController(text: comment.content);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Edit Comment', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextField(
            controller: controller,
            maxLines: null,
            autofocus: true,
            style: const TextStyle(fontSize: 15, height: 1.4),
            decoration: const InputDecoration(
              hintText: 'Enter comment...',
              border: InputBorder.none,
              contentPadding: EdgeInsets.all(16),
            ),
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryRed,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              final newContent = controller.text.trim();
              if (newContent.isNotEmpty && newContent != comment.content) {
                await FirestoreService().updateComment(post.id, comment.id, newContent);
                if (context.mounted) Navigator.pop(ctx);
              } else if (newContent == comment.content) {
                Navigator.pop(ctx); // No changes made
              }
            },
            child: const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showDeleteCommentDialog(BuildContext context, PostModel post, CommentModel comment) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Comment?', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text(
          'Are you sure you want to delete this comment? This cannot be undone.',
          style: TextStyle(height: 1.4),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () async {
              await FirestoreService().deleteComment(post.id, comment.id);
              if (context.mounted) Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

// Modern horizontal action button
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onPressed;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}