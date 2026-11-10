import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../core/ui_helpers.dart';
import '../../models/server_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/server_detail_provider.dart';
import '../../widgets/common.dart';
import '../../widgets/rating_dialog.dart';
import '../../widgets/user_avatar.dart';

/// The members tab of a server, where members can rate each other.
class ServerMembersView extends StatelessWidget {
  const ServerMembersView({super.key});

  Future<void> _rate(BuildContext context, MemberModel member) async {
    final detail = context.read<ServerDetailProvider>();
    final existing = detail.myRatingFor(member.user.id);
    final result = await showRatingDialog(
      context,
      memberName: member.user.fullName,
      initialScore: existing?.score,
      initialComment: existing?.comment,
    );
    if (result == null || !context.mounted) return;
    try {
      if (result.isRemoval) {
        await detail.removeRating(member.user.id);
      } else {
        await detail.rate(member.user.id, result.score!, result.comment);
      }
      // The member's average changed too.
      await detail.loadMembers();
      if (context.mounted) {
        showInfoSnack(
          context,
          result.isRemoval ? 'Rating removed.' : 'Thanks for rating!',
        );
      }
    } catch (e) {
      if (context.mounted) showErrorSnack(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final detail = context.watch<ServerDetailProvider>();
    final myId = context.watch<AuthProvider>().userModel?.id;

    if (detail.membersLoading) return const BrandSpinner();

    final members = detail.members;
    return RefreshIndicator(
      color: AppColors.purple600,
      onRefresh: detail.loadMembers,
      child: members.isEmpty
          ? LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: SizedBox(
                  height: constraints.maxHeight,
                  child: EmptyState(
                    icon: detail.membersError != null
                        ? Icons.cloud_off_rounded
                        : Icons.people_rounded,
                    message: detail.membersError ?? 'No members found.',
                  ),
                ),
              ),
            )
          : ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: members.length,
              itemBuilder: (context, index) {
                final member = members[index];
                final user = member.user;
                final isMe = myId == user.id;
                final mine = detail.myRatingFor(user.id);

                return ListTile(
                  leading: UserAvatar.of(user),
                  title: Row(
                    children: [
                      Flexible(
                        child: Text(
                          user.fullName + (isMe ? ' (You)' : ''),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : AppColors.gray900,
                          ),
                        ),
                      ),
                      if (member.isOwner) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.purple600.withAlpha(25),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Owner',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.purple600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  subtitle: Row(
                    children: [
                      Flexible(
                        child: Text(
                          '@${user.username}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isDark
                                ? AppColors.gray400
                                : AppColors.gray500,
                          ),
                        ),
                      ),
                      if (user.ratingCount > 0) ...[
                        const SizedBox(width: 10),
                        const Icon(
                          Icons.star_rounded,
                          size: 14,
                          color: AppColors.amber400,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '${user.averageRating.toStringAsFixed(1)} (${user.ratingCount})',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? AppColors.gray400
                                : AppColors.gray500,
                          ),
                        ),
                      ],
                    ],
                  ),
                  trailing: isMe
                      ? null
                      : IconButton(
                          icon: Icon(
                            mine == null
                                ? Icons.star_border_rounded
                                : Icons.star_rounded,
                            color: AppColors.amber500,
                          ),
                          tooltip: mine == null
                              ? 'Rate member'
                              : 'Your rating: ${mine.score.toStringAsFixed(1)}',
                          onPressed: () => _rate(context, member),
                        ),
                );
              },
            ),
    );
  }
}
