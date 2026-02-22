// 이 파일은 게시글 상세 페이지입니다.
// 진입 시 GET /posts/{id}, GET /posts/{id}/comments로 데이터 로드, 댓글 등록은 POST /posts/{id}/comments 호출.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'community_page.dart';

const String _kBoardBaseUrl = 'http://10.0.2.2:8000';
/// 댓글 작성 시 사용. 로그인 연동 전 테스트용(1 또는 5 등). 추후 로그인 연동 시 교체
const int _kTempUserId = 1;

class CommunityDetailPage extends StatefulWidget {
  final Post post;

  const CommunityDetailPage({
    super.key,
    required this.post,
  });

  @override
  State<CommunityDetailPage> createState() => _CommunityDetailPageState();
}

class _CommunityDetailPageState extends State<CommunityDetailPage> {
  final TextEditingController _commentController = TextEditingController();

  late Post _post;
  List<Comment> _comments = [];
  bool _postLoaded = false;
  bool _commentsLoaded = false;
  bool _sendingComment = false;

  @override
  void initState() {
    super.initState();
    _post = widget.post;
    _loadPostDetail();
    _loadComments();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  /// 게시글 상세 최신 내용 가져오기 (선택적 반영)
  Future<void> _loadPostDetail() async {
    try {
      final res = await http.get(Uri.parse('$_kBoardBaseUrl/posts/${widget.post.id}'));
      if (!mounted) return;
      if (res.statusCode == 200) {
        final map = jsonDecode(res.body) as Map;
        final title = map['title'] as String? ?? _post.title;
        final content = map['content'] as String? ?? _post.content;
        final userId = map['user_id'] as int?;
        DateTime createdAt = _post.createdAt;
        try {
          if (map['created_at'] != null) {
            createdAt = DateTime.parse(map['created_at'].toString());
          }
        } catch (_) {}
        setState(() {
          _post = Post(
            id: _post.id,
            title: title,
            content: content,
            region: _post.region,
            category: _post.category,
            author: 'User${userId ?? _kTempUserId}',
            createdAt: createdAt,
            comments: _post.comments,
          );
          _postLoaded = true;
        });
      } else {
        setState(() => _postLoaded = true);
      }
    } catch (_) {
      if (mounted) setState(() => _postLoaded = true);
    }
  }

  /// 댓글 목록 가져오기 (replies 평탄화하여 리스트로 표시)
  Future<void> _loadComments() async {
    try {
      final res = await http.get(Uri.parse('$_kBoardBaseUrl/posts/${widget.post.id}/comments'));
      if (!mounted) return;
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map;
        final list = (data['comments'] as List? ?? []) as List;
        final flat = <Comment>[];
        for (final c in list) {
          final m = c as Map;
          final userId = m['user_id'] as int?;
          final content = m['content'] as String? ?? '';
          final createdAt = m['created_at'];
          DateTime dt = DateTime.now();
          if (createdAt != null) {
            try {
              dt = DateTime.parse(createdAt.toString());
            } catch (_) {}
          }
          flat.add(Comment(
            author: 'User${userId ?? 0}',
            content: content,
            createdAt: dt,
          ));
          final replies = m['replies'] as List? ?? [];
          for (final r in replies) {
            final rm = r as Map;
            final ru = rm['user_id'] as int?;
            final rc = rm['content'] as String? ?? '';
            final rca = rm['created_at'];
            DateTime rdt = DateTime.now();
            if (rca != null) {
              try {
                rdt = DateTime.parse(rca.toString());
              } catch (_) {}
            }
            flat.add(Comment(
              author: 'User${ru ?? 0}',
              content: rc,
              createdAt: rdt,
            ));
          }
        }
        setState(() {
          _comments = flat;
          _commentsLoaded = true;
        });
      } else {
        setState(() => _commentsLoaded = true);
      }
    } catch (_) {
      if (mounted) setState(() => _commentsLoaded = true);
    }
  }

  /// 댓글 등록 후 목록 다시 불러오기
  Future<void> _addComment() async {
    final content = _commentController.text.trim();
    if (content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('댓글 내용을 입력해주세요.')),
      );
      return;
    }
    if (_sendingComment) return;
    setState(() => _sendingComment = true);
    try {
      final body = jsonEncode({
        'user_id': _kTempUserId,
        'content': content,
        'parent_comment_id': null,
      });
      final res = await http.post(
        Uri.parse('$_kBoardBaseUrl/posts/${widget.post.id}/comments'),
        headers: {'Content-Type': 'application/json'},
        body: body,
      );
      if (!mounted) return;
      if (res.statusCode >= 200 && res.statusCode < 300) {
        _commentController.clear();
        await _loadComments();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('댓글 등록 실패: ${res.statusCode}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('댓글 등록 중 오류: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sendingComment = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('게시글 상세'),
      ),
      body: Column(
        children: [
          // 게시글 내용 (스크롤 가능)
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 지역과 카테고리
                  Row(
                    children: [
                      // 지역 태그
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _post.region,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // 카테고리 태그
                      _buildCategoryTag(),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // 제목
                  Text(
                    _post.title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 16),
                  
                  // 작성자 및 작성일
                  _buildAuthorInfo(),
                  const Divider(),
                  const SizedBox(height: 16),
                  
                  // 본문
                  Text(
                    _post.content,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 32),
                  
                  // 댓글 섹션 헤더
                  Row(
                    children: [
                      Icon(
                        Icons.comment,
                        size: 20,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '댓글 ${_comments.length}개',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // 댓글 목록 (API에서 불러온 _comments)
                  if (!_commentsLoaded)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24.0),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_comments.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24.0),
                      child: Center(
                        child: Text(
                          '아직 댓글이 없습니다. 첫 댓글을 남겨보세요!',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.grey[500],
                                fontStyle: FontStyle.italic,
                              ),
                        ),
                      ),
                    )
                  else
                    ..._comments.map((comment) => _buildCommentItem(comment)),
                  
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          
          // 댓글 입력 UI (하단 고정)
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  spreadRadius: 1,
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: _buildCommentInput(),
          ),
        ],
      ),
    );
  }

  // 카테고리 태그
  Widget _buildCategoryTag() {
    Color categoryColor = _getCategoryColor(_post.category);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: categoryColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        _post.category,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // 카테고리별 색상 반환
  Color _getCategoryColor(String category) {
    switch (category) {
      case '날씨':
        return Colors.lightBlue;
      case '양도':
        return Colors.orange;
      case '동행':
        return Colors.purple;
      case '후기':
        return Colors.green;
      case 'Q&A':
        return Colors.blue;
      case '선택 안 함':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  // 작성자 정보
  Widget _buildAuthorInfo() {
    return Row(
      children: [
        const Icon(Icons.person, size: 16, color: Colors.grey),
        const SizedBox(width: 4),
        Text(
          _post.author,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 16),
        const Icon(Icons.access_time, size: 16, color: Colors.grey),
        const SizedBox(width: 4),
        Text(
          _formatDate(_post.createdAt),
          style: const TextStyle(
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  // 댓글 아이템 위젯
  Widget _buildCommentItem(Comment comment) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 작성자 아바타
          CircleAvatar(
            radius: 18,
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            child: Text(
              comment.author.isNotEmpty ? comment.author[0] : '?',
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // 댓글 내용 영역
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 작성자 이름과 시간
                Row(
                  children: [
                    Text(
                      comment.author,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[800],
                          ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatDate(comment.createdAt),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[500],
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                // 댓글 내용
                Text(
                  comment.content,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 댓글 입력 UI
  Widget _buildCommentInput() {
    return Row(
      children: [
        // 댓글 입력 필드
        Expanded(
          child: TextField(
            controller: _commentController,
            decoration: InputDecoration(
              hintText: '댓글을 입력하세요...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surface,
            ),
            maxLines: null,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) {
              _addComment();
            },
          ),
        ),
        const SizedBox(width: 8),
        // 전송 버튼
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            onPressed: _addComment,
            icon: const Icon(Icons.send, color: Colors.white),
            tooltip: '댓글 등록',
          ),
        ),
      ],
    );
  }

  // 날짜 포맷팅
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays}일 전';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}시간 전';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}분 전';
    } else {
      return '방금 전';
    }
  }
}



