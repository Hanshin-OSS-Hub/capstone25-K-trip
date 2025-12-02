// 이 파일은 게시글 상세 페이지입니다.
// CommunityPage에서 게시글을 탭했을 때 Navigator.push로 이동하는 페이지입니다.
// 게시글의 전체 내용을 표시하고, 댓글 목록과 댓글 작성 기능을 제공합니다.
// TODO: 추후 백엔드 API 연동 예정

import 'package:flutter/material.dart';
import 'community_page.dart';

class CommunityDetailPage extends StatefulWidget {
  final Post post; // 게시글 객체 (직접 참조하여 댓글을 추가)

  const CommunityDetailPage({
    super.key,
    required this.post,
  });

  @override
  State<CommunityDetailPage> createState() => _CommunityDetailPageState();
}

class _CommunityDetailPageState extends State<CommunityDetailPage> {
  // 댓글 입력을 위한 TextEditingController
  final TextEditingController _commentController = TextEditingController();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  // === 댓글 추가 ===
  void _addComment() {
    final content = _commentController.text.trim();
    
    if (content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('댓글 내용을 입력해주세요.')),
      );
      return;
    }

    // Post 객체의 comments 리스트에 직접 추가
    setState(() {
      widget.post.comments.add(
        Comment(
          author: '익명${widget.post.comments.length + 1}',
          content: content,
          createdAt: DateTime.now(),
        ),
      );
    });

    // 입력창 비우기
    _commentController.clear();
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
                          widget.post.region,
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
                    widget.post.title,
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
                    widget.post.content,
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
                        '댓글 ${widget.post.comments.length}개',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // 댓글 목록
                  if (widget.post.comments.isEmpty)
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
                    ...widget.post.comments.map((comment) => _buildCommentItem(comment)),
                  
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
    Color categoryColor = _getCategoryColor(widget.post.category);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: categoryColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        widget.post.category,
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
          widget.post.author,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 16),
        const Icon(Icons.access_time, size: 16, color: Colors.grey),
        const SizedBox(width: 4),
        Text(
          _formatDate(widget.post.createdAt),
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
              comment.author[0],
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


